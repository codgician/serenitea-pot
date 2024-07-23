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
      # All Darwin modules for building system
      mkDarwinInputModules = stable: with inputs; [
        agenix.darwinModules.default
        (if stable then home-manager.darwinModules.home-manager
        else home-manager-unstable.darwinModules.home-manager)
      ];

      # All NixOS modules for building system
      mkNixosInputModules = stable: with inputs; [
        nur.nixosModules.nur
        impermanence.nixosModules.impermanence
        (if stable then home-manager.nixosModules.home-manager
        else home-manager-unstable.nixosModules.home-manager)
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [
              plasma-manager.homeManagerModules.plasma-manager
            ];
          };
        }
        disko.nixosModules.disko
        agenix.nixosModules.default
        lanzaboote.nixosModules.lanzaboote
        nixos-wsl.nixosModules.wsl
        nixvirt.nixosModules.default
        vscode-server.nixosModules.default
      ];

      # Modules provided by this flake
      darwinModules = import ./modules/darwin { inherit lib; };
      nixosModules = import ./modules/nixos { inherit lib; };

      # All modules
      mkDarwinAllModules = stable: [ darwinModules.default ] ++ (mkDarwinInputModules stable);
      mkNixosAllModules = stable: [ nixosModules.default ] ++ (mkNixosInputModules stable);

      mkLib = nixpkgs: nixpkgs.lib // (import ./lib { inherit nixpkgs; });
      mkPkgs = nixpkgs: system: (import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        flake.source = nixpkgs.outPath;
      }) // { lib = mkLib nixpkgs; };
      lib = mkLib inputs.nixpkgs;
    in
    rec {
      # Modules
      inherit darwinModules nixosModules;

      # System configurations
      inherit (import ./hosts {
        inherit inputs lib mkLib mkPkgs;
        mkDarwinModules = mkDarwinAllModules;
        mkNixosModules = mkNixosAllModules;
      }) darwinConfigurations nixosConfigurations;

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        isDarwin = inputs.nixpkgs.legacyPackages.${system}.stdenvNoCC.isDarwin;
        nixpkgs = if isDarwin then inputs.nixpkgs-darwin else inputs.nixpkgs;
        lib = mkLib nixpkgs;
        pkgs = mkPkgs nixpkgs system;
        agenixCli = agenix.packages.${system}.default;
      in
      rec {
        # Development shell: `nix develop .#name`
        devShells =
          let commonPkgs = with pkgs; [ agenixCli ];
          in {
            default = pkgs.mkShell {
              buildInputs = commonPkgs;
            };

            cloud = pkgs.mkShell {
              buildInputs = with pkgs; [
                (lib.optionals (!isDarwin) azure-cli)
                azure-storage-azcopy
                cf-terraforming
                jq
                hcl2json
                (terraform.withPlugins (p: [
                  p.azurerm
                  p.cloudflare
                  p.proxmox
                  p.utils
                ]))
              ] ++ commonPkgs;
            };
          };

        # Formatter: `nix fmt`
        formatter = pkgs.nixpkgs-fmt;

        # Packages: `nix build .#pkgName`
        packages = {
          # Terraform configurations
          terraformConfiguration = terranix.lib.terranixConfiguration {
            inherit system pkgs;
            extraArgs = { inherit lib; };
            modules = [ ./terraform ];
          };

          # Documentations
          darwinDocs =
            let
              eval = import "${inputs.darwin}/eval-config.nix" {
                inherit lib;
                specialArgs = { inherit lib; };
                modules = (mkDarwinAllModules true) ++ [{
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
                modules = mkNixosAllModules true;
              };
            in
            (pkgs.nixosOptionsDoc { options = eval.options.codgician; }).optionsCommonMark;
        };

        # Apps: `nix run .#appName`
        apps = {
          # nix repl for debugging
          repl = inputs.flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "repl" ''
              nix repl --expr "builtins.getFlake (toString $(${pkgs.git}/bin/git rev-parse --show-toplevel))"
            '';
          };

          # terraform apply
          terraform-apply = let terraformAgeFileName = "terraformEnv.age"; in
            inputs.flake-utils.lib.mkApp {
              drv = pkgs.writeShellScriptBin "terraform-apply" ''
                # Decrypt terraform secrets and set environment variables
                dir=$(${pkgs.coreutils}/bin/pwd)
                cd ${./secrets}
                [ -f "./${terraformAgeFileName}" ] || { echo "${terraformAgeFileName} not found under ${./secrets}"; exit 1; }
                envs=$(${agenixCli}/bin/agenix -d terraformEnv.age)
                [ ! -z "$envs" ] || { echo "Terraform envs should not be empty. Decryption failure?"; exit 1; }
                export $(echo $envs | xargs)
                cd $dir

                # Apply terraform configurations
                [ ! -e config.tf.json ] || rm -f config.tf.json
                cp ${packages.terraformConfiguration} config.tf.json \
                  && ${pkgs.terraform}/bin/terraform init \
                  && ${pkgs.terraform}/bin/terraform apply
              '';
            };
        };
      });
}
