{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    nixpkgs-nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    impermanence.url = "github:nix-community/impermanence";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";

    mobile-nixos = {
      url = "github:codgician/mobile-nixos/fix-depmod";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
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
      mkPkgs = nixpkgs: system: (import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
        flake.source = nixpkgs.outPath;
      });
      lib = mkLib inputs.nixpkgs;

      # Package overlays
      overlays = [ (self: super: { lib = mkLib super; }) ]
        ++ (builtins.map (x: import x { inherit inputs; }) (with lib.codgician; getNixFilePaths overlaysDir));

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

      # All Darwin modules for building system
      mkDarwinInputModules = stable: with inputs;
        (mkHomeManagerModules "darwinModules" stable [ ]) ++ [
          agenix.darwinModules.default
        ];

      # All NixOS modules for building system
      mkNixosInputModules = stable: with inputs;
        (mkHomeManagerModules "nixosModules" stable [
          # Home Manager modules
          plasma-manager.homeManagerModules.plasma-manager
        ]) ++ [
          # NixOS modules
          nur.nixosModules.nur
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          agenix.nixosModules.default
          lanzaboote.nixosModules.lanzaboote
          nixos-wsl.nixosModules.wsl
          nixvirt.nixosModules.default
          vscode-server.nixosModules.default
        ];

      # All modules
      modules = import ./modules { inherit lib; };
      mkDarwinModules = stable: [ modules.darwin ] ++ (mkDarwinInputModules stable);
      mkNixosModules = stable: [ modules.nixos ] ++ (mkNixosInputModules stable);
    in
    {
      # System configurations
      inherit (import ./hosts {
        inherit inputs lib mkLib overlays;
        inherit mkDarwinModules mkNixosModules;
      }) darwinConfigurations nixosConfigurations;

      # Export custom library namespace
      lib = { inherit (lib) codgician; };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        isDarwin = inputs.nixpkgs.legacyPackages.${system}.stdenvNoCC.isDarwin;
        nixpkgs = if isDarwin then inputs.nixpkgs-darwin else inputs.nixpkgs;
        lib = mkLib nixpkgs;
        pkgs = mkPkgs nixpkgs system;
      in
      rec {
        # Development shell: `nix develop .#name`
        devShells = (import ./shells { inherit lib pkgs inputs; outputs = self; });

        # Formatter: `nix fmt`
        formatter = pkgs.nixpkgs-fmt;

        # Packages: `nix build .#pkgName`
        packages = {
          # Terraform configuration
          terraformConfiguration = (import ./terraform { inherit lib pkgs terranix; });

          # Documentations
          darwinDocs =
            let
              eval = import "${inputs.darwin}/eval-config.nix" {
                inherit lib;
                specialArgs = { inherit lib; };
                modules = (mkDarwinModules true) ++ [{
                  nixpkgs = {
                    source = lib.mkDefault nixpkgs;
                    inherit system;
                  };
                }];
              };
            in
            (pkgs.nixosOptionsDoc { options = eval.options.codgician; }).optionsCommonMark;

          nixosDocs =
            let
              eval = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix" {
                inherit system;
                specialArgs = { inherit lib; };
                modules = mkNixosModules true;
              };
            in
            (pkgs.nixosOptionsDoc { options = eval.options.codgician; }).optionsCommonMark;
        };

        # Apps: `nix run .#appName`
        apps = (import ./apps { inherit lib pkgs inputs; outputs = self; });
      });
}
