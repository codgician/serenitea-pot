{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
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
      url = "github:nixos/mobile-nixos/development";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
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

  outputs =
    inputs @ { self
    , nixos-hardware
    , mobile-nixos
    , darwin
    , nur
    , nur-xddxdd
    , agenix
    , impermanence
    , vscode-server
    , flake-utils
    , disko
    , lanzaboote
    , terranix
    , nixos-wsl
    , ...
    }:
    let
      mkConfig = inputs.nixpkgs.lib.mapAttrs (name: value: value name);

      # Basic configs for each host
      basicConfig = system: hostName: { config, ... }: {
        nix = {
          settings.auto-optimise-store = true;
          extraOptions = "experimental-features = nix-command flakes";
        };

        networking.hostName = hostName;

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Common configurations for macOS systems
      darwinSystem =
        { extraModules ? [ ]
        , system
        , nixpkgs ? inputs.nixpkgs-darwin
        , home-manager ? inputs.home-manager
        }: hostName:
        let
          lib = nixpkgs.lib;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit lib pkgs inputs self system; };
          modules = [
            (import ./modules/darwin)
            (basicConfig system hostName)

            home-manager.darwinModules.home-manager
            agenix.darwinModules.default

            ({ config, ... }: {
              nix.settings.sandbox = false;
              services.nix-daemon.enable = true;
            })
          ] ++ extraModules;
        };

      # Common configurations for NixOS systems
      nixosSystem =
        { extraModules ? [ ]
        , system
        , nixpkgs ? inputs.nixpkgs
        , home-manager ? inputs.home-manager
        , inheritPkgs ? true
        }: hostName:
        let
          lib = nixpkgs.lib;
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              # todo: remove after onboarding 24.05
              permittedInsecurePackages = lib.optionals (lib.version < "24.05") [ "nix-2.15.3" ];
            };

            overlays = [
              (final: prev: {
                nur = import nur {
                  nurpkgs = prev;
                  pkgs = prev;
                  repoOverrides = { xddxdd = import inputs.nur-xddxdd { pkgs = prev; }; };
                };
              })
            ];
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit lib inputs self system; } // lib.optionalAttrs inheritPkgs { inherit pkgs; };
          modules = [
            # Third-party binary caches
            ({ config, ... }: {
              nix.settings = {
                sandbox = true;
                substituters = [
                  "https://xddxdd.cachix.org"
                  "https://nix-community.cachix.org"
                ];
                trusted-public-keys = [
                  "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8="
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            })

            (import ./modules/nixos)
            (basicConfig system hostName)

            nur.nixosModules.nur
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            agenix.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            nixos-wsl.nixosModules.wsl
            vscode-server.nixosModules.default

            ({ config, ... }: {
              # Set flake for auto upgrade
              system.autoUpgrade.flake = "github:codgician/nix-fleet";
            })
          ] ++ extraModules;
        };
    in
    {
      # macOS machines
      darwinConfigurations = mkConfig {
        # aarch64 machines
        "furina" = darwinSystem {
          system = "aarch64-darwin";
          extraModules = [ ./hosts/furina ];
        };

        # x86_64 machines
        "raiden-ei" = darwinSystem {
          system = "x86_64-darwin";
          extraModules = [ ./hosts/raiden-ei ];
        };
      };

      # NixOS machines
      nixosConfigurations = mkConfig {
        # aarch64 machines
        "focalors" = nixosSystem {
          system = "aarch64-linux";
          extraModules = [ ./hosts/focalors ];
          nixpkgs = inputs.nixpkgs-nixos-unstable;
          home-manager = inputs.home-manager-unstable;
        };

        "noir" = nixosSystem {
          system = "aarch64-linux";
          extraModules = [
            (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
            ./hosts/noir
          ];
          nixpkgs = inputs.nixpkgs-nixos-unstable;
          home-manager = inputs.home-manager-unstable;
          inheritPkgs = false;
        };

        # x86_64 machines
        "paimon" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/paimon ];
        };

        "nahida" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/nahida ];
        };

        "lumine" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/lumine ];
        };
        
        "wsl" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/wsl ];
        };
      };

    } // flake-utils.lib.eachDefaultSystem (system:
    let
      nixpkgs =
        if inputs.nixpkgs.legacyPackages.${system}.stdenvNoCC.isDarwin
        then inputs.nixpkgs-darwin
        else inputs.nixpkgs;
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          # todo: remove after onboarding 24.05
          permittedInsecurePackages = lib.optionals (lib.version < "24.05") [ "nix-2.15.3" ];
        };
      };
      agenixCli = agenix.packages.${system}.default;
    in
    {
      # Development shell: `nix develop .#name`
      devShells =
        let commonPkgs = with pkgs; [ rnix-lsp agenixCli ];
        in {
          default = pkgs.mkShell {
            buildInputs = commonPkgs;
          };

          cloud = pkgs.mkShell {
            buildInputs = with pkgs; [
              azure-cli
              azure-storage-azcopy
              jq
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
        # Terraform profiles
        terraformProfiles = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [ ./terraform/config.nix ];
        };
      };

      # Apps: `nix run .#appName`
      apps = {
        repl = inputs.flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "repl" ''
            confnix=$(mktemp)
            echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
            trap "rm $confnix" EXIT
            nix repl $confnix
          '';
        };
      };
    });
}
