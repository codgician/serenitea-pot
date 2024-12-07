{
  description = "❄️ Home to codgician's nix-managed device profiles";

  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.saumon.network/proxmox-nixos"
      "https://codgician.cachix.org"
      "https://cuda-maintainers.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "proxmox-nixos:nveXDuVVhFDRFx8Dn19f1WDEaNRJjPrF2CPD2D+m1ys="
      "codgician.cachix.org-1:v4RtwkbJZJwfDxH5hac1lHehIX6JoSL726vk1ZctN8Y="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";

    proxmox-nixos = {
      url = "github:SaumonNet/proxmox-nixos";
      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        utils.follows = "flake-utils";
      };
    };

    mobile-nixos = {
      url = "github:codgician/mobile-nixos/fix-depmod";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-nixos-unstable";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    impermanence.url = "github:nix-community/impermanence";

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "darwin";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nur.url = "github:nix-community/NUR";
    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-parts.follows = "flake-parts";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs = inputs @ { self, agenix, terranix, ... }:
    let
      # Extending lib
      mkLib = nixpkgs: (import ./lib { lib = nixpkgs.lib; inherit inputs; });
      lib = mkLib inputs.nixpkgs;

      # Make home-manager module
      mkHomeManagerModules = with inputs; modulesName: stable: sharedModules:
        let homeManager = if stable then home-manager else home-manager-unstable;
        in [
          (homeManager.${modulesName}.home-manager)
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              inherit sharedModules;
            };
          }
        ];

      # All modules
      myModules = import ./modules { inherit lib; };

      # All Darwin modules for building system
      mkDarwinModules = stable:
        (mkHomeManagerModules "darwinModules" stable [
          # Home Manager modules
        ]) ++ [
          # Darwin modules
          myModules.darwin
          agenix.darwinModules.default
        ];

      # All NixOS modules for building system
      mkNixosModules = stable: with inputs;
        (mkHomeManagerModules "nixosModules" stable [
          # Home Manager modules
          plasma-manager.homeManagerModules.plasma-manager
        ]) ++ [
          # NixOS modules
          myModules.nixos
          nur.modules.nixos.default
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          agenix.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          nixos-generators.nixosModules.all-formats
          nixos-wsl.nixosModules.wsl
          nixvirt.nixosModules.default
          vscode-server.nixosModules.default
          proxmox-nixos.nixosModules.proxmox-ve
          ({ system, ... }: {
            nixpkgs.overlays = [ proxmox-nixos.overlays.${system} ];
          })
        ];
    in
    {
      # System configurations
      inherit (import ./hosts {
        inherit inputs mkLib;
        inherit mkDarwinModules mkNixosModules;
        outputs = self;
      }) darwinConfigurations nixosConfigurations;

      # Export custom library
      inherit lib;

      # Apps: `nix run .#appName`
      apps = (import ./apps { inherit lib inputs; outputs = self; });

      # Development shell: `nix develop .#name`
      devShells = lib.codgician.forAllSystems (pkgs: import ./shells {
        inherit lib pkgs inputs;
        outputs = self;
      });

      # Formatter: `nix fmt`
      formatter = lib.codgician.forAllSystems (pkgs: pkgs.nixpkgs-fmt);

      # Packages: `nix build .#pkgName`
      packages = (import ./packages { inherit lib inputs; outputs = self; });
    };
}
