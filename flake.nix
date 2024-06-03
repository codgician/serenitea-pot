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

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "darwin";
        home-manager.follows = "home-manager";
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
        flake-utils.follows = "flake-utils";
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

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs @ { self, flake-utils, agenix, terranix, ... }:
    let
      darwinModules.default = import ./modules/darwin;
      nixosModules.default = import ./modules/nixos;
      mkLib = nixpkgs: nixpkgs.lib // (import ./lib { inherit nixpkgs; });
      mkPkgs = nixpkgs: system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        flake.source = nixpkgs.outPath;
      };
      lib = mkLib inputs.nixpkgs;
    in
    {
      inherit darwinModules nixosModules;
      inherit (import ./hosts { inherit inputs lib mkLib mkPkgs darwinModules nixosModules; }) darwinConfigurations nixosConfigurations;
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
