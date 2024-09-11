{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      url = "github:nix-community/home-manager/release-24.05";
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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-ovmf.follows = "nixpkgs-nixos-unstable";
      };
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
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs @ { self, flake-utils, agenix, terranix, ... }:
    let
      # Extending lib
      mkLib = nixpkgs: (import ./lib { lib = nixpkgs.lib; });
      lib = mkLib inputs.nixpkgs;

      # Package overlays
      overlays = [ (self: super: { lib = mkLib super; }) ]
        ++ (builtins.map (x: import x { inherit inputs; }) (with lib.codgician; getNixFilePaths overlaysDir));

      # Make package universe
      mkPkgs = nixpkgs: system: (import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
        flake.source = nixpkgs.outPath;
      });

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
          nur.nixosModules.nur
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
        inherit inputs mkLib overlays;
        inherit mkDarwinModules mkNixosModules;
      }) darwinConfigurations nixosConfigurations;

      # Export custom library namespace
      lib = { inherit (lib) codgician; };

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        inherit (inputs) nixpkgs;
        pkgs = mkPkgs nixpkgs system;
      in
      {
        # Development shell: `nix develop .#name`
        devShells = (import ./shells { inherit lib pkgs inputs; outputs = self; });

        # Formatter: `nix fmt`
        formatter = pkgs.nixpkgs-fmt;

        # Packages: `nix build .#pkgName`
        packages = {
          # Terraform configuration
          terraformConfiguration = (import ./terraform { inherit lib pkgs terranix; });
        };

        # Apps: `nix run .#appName`
        apps = (import ./apps { inherit lib pkgs inputs; outputs = self; });
      });
}
