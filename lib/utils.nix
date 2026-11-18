{
  lib,
  nixpkgs,
  inputs,
  outputs,
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

  # Overlays applied to both the stable and the unstable package set
  getCommonOverlays =
    system:
    [
      (final: prev: { nur.repos.codgician = import inputs.nur-codgician { pkgs = prev; }; })
      inputs.nix-vscode-extensions.overlays.default
    ]
    ++ (lib.optional (isLinuxSystem system) inputs.proxmox-nixos.overlays.${system})
    ++ [ (mkUnstableOverlay system) ];

  # nixpkgs unstable no longer supports x86_64-darwin after 26.05, so that
  # system keeps resolving `pkgs.unstable` to the release input.
  mkUnstableOverlay = system: final: prev: {
    unstable = import (if system == "x86_64-darwin" then inputs.nixpkgs else inputs.nixpkgs-unstable) {
      inherit system;
      config = {
        allowUnfree = true;
        # Inherit CUDA/ROCm config from the stable package set
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
    system: config:
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
  # it embeds evaluate nixpkgs once instead of once each.
  pkgsFor = lib.genAttrs allSystems (system: mkPkgs system { });
  cudaPkgsFor = lib.genAttrs linuxSystems (system: mkPkgs system { cudaSupport = true; });

  homeManagerDefaults = sharedModules: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      inherit sharedModules;
    };
  };

  # Modules imported by every Darwin host
  darwinModules = with inputs; [
    home-manager.darwinModules.home-manager
    (homeManagerDefaults [ ])
    outputs.modules.darwin
    sops-nix.darwinModules.sops
  ];

  # Modules imported by every NixOS host
  nixosModules =
    with inputs;
    [
      home-manager.nixosModules.home-manager
      (homeManagerDefaults [ plasma-manager.homeModules.plasma-manager ])
      outputs.modules.nixos
      impermanence.nixosModules.impermanence
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      lanzaboote.nixosModules.lanzaboote
      nixos-wsl.nixosModules.wsl
      nixvirt.nixosModules.default
      vscode-server.nixosModules.default
      proxmox-nixos.nixosModules.proxmox-ve
    ]
    ++ (builtins.attrValues nur-codgician.nixosModules);

  # Common configurations for macOS systems
  mkDarwinSystem =
    {
      hostName,
      system,
      modules ? [ ],
    }:
    inputs.darwin.lib.darwinSystem {
      inherit system lib;
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          system
          ;
      };
      modules =
        darwinModules
        ++ modules
        ++ [
          {
            networking.hostName = hostName;
            nixpkgs.pkgs = pkgsFor.${system};
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
    }:
    nixpkgs.lib.nixosSystem {
      inherit system lib;
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          system
          ;
      };
      modules =
        nixosModules
        ++ modules
        ++ [
          {
            networking.hostName = hostName;
            nixpkgs.pkgs = (if cudaSupport then cudaPkgsFor else pkgsFor).${system};
          }
        ];
    };

  # Generate attribute set for specified systems
  forSystems = systems: func: lib.genAttrs systems (system: func pkgsFor.${system});
  forAllSystems = forSystems allSystems;
  forLinuxSystems = forSystems linuxSystems;
}
