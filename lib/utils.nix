{
  lib,
  inputs,
  outputs,
  mkLib,
  ...
}:
rec {
  # List of supported systems
  darwinSystems = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];
  linuxSystems = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  isLinuxSystem = lib.hasSuffix "-linux";
  allSystems = darwinSystems ++ linuxSystems;

  # Inputs a host is built from. A manifest with `stable = false` takes the
  # unstable ones, so the whole machine follows nixos-unstable.
  channels = {
    stable = {
      inherit lib;
      inherit (inputs) nixpkgs home-manager darwin;
    };
    unstable = {
      lib = mkLib inputs.nixpkgs-unstable;
      nixpkgs = inputs.nixpkgs-unstable;
      home-manager = inputs.home-manager-unstable;
      darwin = inputs.darwin-unstable;
    };
  };

  # Overlays applied to every package set, including `pkgs.master`
  getCommonOverlays =
    system:
    [
      (final: prev: { nur.repos.codgician = import inputs.nur-codgician { pkgs = prev; }; })
      inputs.nix-vscode-extensions.overlays.default
    ]
    ++ lib.optional (isLinuxSystem system) inputs.proxmox-nixos.overlays.${system};

  # nixpkgs unstable and master no longer support x86_64-darwin after 26.05,
  # so there they resolve to the release, which is then its own unstable.
  isUnstable = channelName: system: channelName == "unstable" || system == "x86_64-darwin";

  masterOverlay = system: final: prev: {
    master = import (if system == "x86_64-darwin" then inputs.nixpkgs else inputs.nixpkgs-master) {
      inherit system;
      config = {
        allowUnfree = true;
        # Inherit CUDA/ROCm config from the package set it is added to
        cudaSupport = prev.config.cudaSupport or false;
        rocmSupport = prev.config.rocmSupport or false;
      };
      overlays = getCommonOverlays system;
    };
  };

  # Overlays take packages from `unstable` only through these, each an overlay
  # that does nothing in an unstable set: a package is never defined as itself.
  # `fromUnstable names` takes top-level packages, `.python` Python packages
  # and `.kernel` kernel modules.
  mkFromUnstable =
    unstable: own:
    let
      take = overlay: if own then (_: _: { }) else overlay;
    in
    {
      __functor = _: names: take (_: _: lib.genAttrs names (name: unstable.${name}));

      python =
        names:
        take (
          final: prev: {
            pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
              (pyfinal: pyprev: lib.genAttrs names (name: unstable."${pyprev.python.pythonAttr}Packages".${name}))
            ];
          }
        );

      kernel =
        names:
        take (
          final: prev: {
            linuxKernel = prev.linuxKernel // {
              packagesFor =
                kernel:
                (prev.linuxKernel.packagesFor kernel).extend (
                  lpfinal: lpprev:
                  lib.genAttrs names (
                    name: unstable.linuxPackages.${name}.override { inherit (lpprev) kernel kernelModuleMakeFlags; }
                  )
                );
            };
          }
        );
    };

  # `pkgs.unstable` is the package set an unstable host uses, overlays
  # included; in an unstable set it is the set itself.
  mkPkgs =
    channelName: system: config:
    let
      channel = channels.${channelName};
      own = isUnstable channelName system;
      unstable =
        if own then
          null
        else
          packageSets.unstable.${system}.${if config.cudaSupport or false then "cuda" else "default"};
      fromUnstable = mkFromUnstable unstable own;
    in
    import channel.nixpkgs {
      inherit system;
      overlays =
        getCommonOverlays system
        ++ [
          (masterOverlay system)
          (final: prev: { unstable = if own then final else unstable; })
        ]
        ++ map (
          path:
          import path {
            inherit (channel) lib;
            inherit
              inputs
              system
              outputs
              fromUnstable
              ;
          }
        ) (lib.codgician.getFolderPaths ../overlays)
        ++ [ inputs.nur-codgician.overlays.kernel-modules ];
      config = {
        allowUnfree = true;
      }
      // config;
    };

  # Every flake output takes its packages from these sets. Hosts receive them
  # through `nixpkgs.pkgs`, so a host, its specialisations and the containers
  # it embeds evaluate nixpkgs once instead of once each. A set is only
  # instantiated when something reads it.
  packageSets = lib.mapAttrs (
    channelName: _:
    lib.genAttrs allSystems (system: {
      default = mkPkgs channelName system { };
      cuda = mkPkgs channelName system { cudaSupport = true; };
    })
  ) channels;
  pkgsFor = lib.mapAttrs (_: sets: sets.default) packageSets.stable;

  homeManagerDefaults = sharedModules: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      inherit sharedModules;
    };
  };

  # Modules imported by every Darwin host
  mkDarwinModules = home-manager: [
    home-manager.darwinModules.home-manager
    (homeManagerDefaults [ ])
    outputs.modules.darwin
    inputs.sops-nix.darwinModules.sops
  ];

  # Modules imported by every NixOS host
  mkNixosModules =
    home-manager:
    [
      home-manager.nixosModules.home-manager
      (homeManagerDefaults [ inputs.plasma-manager.homeModules.plasma-manager ])
      outputs.modules.nixos
    ]
    ++ (with inputs; [
      impermanence.nixosModules.impermanence
      disko.nixosModules.disko
      noctalia.nixosModules.default
      sops-nix.nixosModules.sops
      lanzaboote.nixosModules.lanzaboote
      nixos-wsl.nixosModules.wsl
      nixvirt.nixosModules.default
      vscode-server.nixosModules.default
      proxmox-nixos.nixosModules.proxmox-ve
    ])
    ++ (builtins.attrValues inputs.nur-codgician.nixosModules);
  nixosModules = mkNixosModules inputs.home-manager;

  # Common configurations for macOS systems
  mkDarwinSystem =
    {
      hostName,
      system,
      modules ? [ ],
      stable ? true,
    }:
    let
      channelName = if stable then "stable" else "unstable";
      channel = channels.${channelName};
    in
    channel.darwin.lib.darwinSystem {
      inherit system;
      inherit (channel) lib;
      specialArgs = {
        inherit
          inputs
          outputs
          system
          ;
        inherit (channel) lib;
      };
      modules =
        mkDarwinModules channel.home-manager
        ++ modules
        ++ [
          {
            networking.hostName = hostName;
            nixpkgs.pkgs = packageSets.${channelName}.${system}.default;
          }
        ];
    };

  # Common configurations for NixOS systems
  mkNixosSystem =
    {
      hostName,
      system,
      modules ? [ ],
      cudaSupport ? false,
      stable ? true,
    }:
    let
      channelName = if stable then "stable" else "unstable";
      channel = channels.${channelName};
    in
    channel.nixpkgs.lib.nixosSystem {
      inherit system;
      inherit (channel) lib;
      specialArgs = {
        inherit
          inputs
          outputs
          system
          ;
        inherit (channel) lib;
      };
      modules =
        mkNixosModules channel.home-manager
        ++ modules
        ++ [
          {
            networking.hostName = hostName;
            nixpkgs.pkgs = packageSets.${channelName}.${system}.${if cudaSupport then "cuda" else "default"};
          }
        ];
    };

  # Generate attribute set for specified systems
  forSystems = systems: func: lib.genAttrs systems (system: func pkgsFor.${system});
  forAllSystems = forSystems allSystems;
  forLinuxSystems = forSystems linuxSystems;
}
