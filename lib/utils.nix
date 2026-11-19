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

  # Overlays applied to every package set, including `pkgs.master` and
  # `pkgs.unstable` themselves
  getCommonOverlays =
    system:
    [
      (final: prev: { nur.repos.codgician = import inputs.nur-codgician { pkgs = prev; }; })
      inputs.nix-vscode-extensions.overlays.default
    ]
    ++ (lib.optional (isLinuxSystem system) inputs.proxmox-nixos.overlays.${system})
    ++ [
      (mkBranchOverlay "master" inputs.nixpkgs-master system)
      (mkBranchOverlay "unstable" inputs.nixpkgs-unstable system)
    ];

  # `pkgs.<name>` is the package set of another nixpkgs branch. nixpkgs
  # unstable and master no longer support x86_64-darwin after 26.05, so that
  # system keeps resolving them to the release input.
  mkBranchOverlay = name: branch: system: final: prev: {
    ${name} = import (if system == "x86_64-darwin" then inputs.nixpkgs else branch) {
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

  mkOverlays =
    system:
    (getCommonOverlays system)
    ++ (builtins.map (
      x:
      import x {
        inherit
          inputs
          lib
          system
          outputs
          ;
      }
    ) (lib.codgician.getFolderPaths ../overlays))
    ++ [ inputs.nur-codgician.overlays.kernel-modules ];

  mkPkgs =
    nixpkgs: system: config:
    import nixpkgs {
      inherit system;
      overlays = mkOverlays system;
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
    _: channel:
    lib.genAttrs allSystems (system: {
      default = mkPkgs channel.nixpkgs system { };
      cuda = mkPkgs channel.nixpkgs system { cudaSupport = true; };
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
