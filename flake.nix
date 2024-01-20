{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      inputs.flake-utils.follows = "flake-utils";
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
      lib = inputs.nixpkgs.lib;
      mkConfig = lib.mapAttrs (name: value: value name);

      darwinModules = import ./modules/darwin;
      nixosModules = import ./modules/nixos;

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
        , home-manager ? inputs.home-manager-darwin
        , inheritPkgs ? true
        }: hostName:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit lib inputs self system nixpkgs home-manager; } // lib.optionalAttrs inheritPkgs { inherit pkgs; };
          modules = [
            darwinModules
            (basicConfig system hostName)

            home-manager.darwinModules.home-manager
            agenix.darwinModules.default

            ({ config, ... }: {
              nix.settings.sandbox = true;
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
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;

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
          specialArgs = { inherit lib inputs self system nixpkgs home-manager; } // lib.optionalAttrs inheritPkgs { inherit pkgs; };
          modules = [
            # Third-party binary caches
            ({ config, ... }: {
              nix.settings = {
                sandbox = true;
                substituters = [
                  config.nur.repos.xddxdd._meta.url
                  "https://nix-community.cachix.org"
                ];
                trusted-public-keys = [
                  config.nur.repos.xddxdd._meta.publicKey
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            })

            nixosModules
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
      inherit darwinModules nixosModules;

      # macOS machines
      darwinConfigurations = mkConfig {
        "Shijia-Mac" = darwinSystem {
          system = "aarch64-darwin";
          extraModules = [ ./hosts/mac/default.nix ];
        };

        "MacRun" = darwinSystem {
          system = "x86_64-darwin";
          extraModules = [ ./hosts/runners/macrun.nix ];
        };
      };

      # NixOS machines
      nixosConfigurations = mkConfig {
        # x86_64 machines
        "mona" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/mona/default.nix ];
        };

        "violet" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/violet/default.nix ];
        };

        "wsl" = nixosSystem {
          system = "x86_64-linux";
          extraModules = [ ./hosts/wsl/default.nix ];
        };

        # aarch64 machines
        # todo: fix noir
        # "noir" = nixosSystem {
        #   system = "aarch64-linux";
        #   extraModules = [
        #     (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
        #     ./hosts/noir/default.nix
        #   ];
        #   nixpkgs = inputs.nixpkgs;
        #   home-manager = inputs.home-manager;
        #   inheritPkgs = false;
        # };
      };

    } // flake-utils.lib.eachDefaultSystem (system:
    let
      nixpkgs =
        if inputs.nixpkgs.legacyPackages.${system}.stdenvNoCC.isDarwin
        then inputs.nixpkgs-darwin
        else inputs.nixpkgs;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      agenixCli = agenix.packages.${system}.default;
    in
    {
      # Development shell: `nix develop`
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          rnix-lsp
          agenixCli
          (terraform.withPlugins (p: [ p.azurerm p.cloudflare ]))
        ];
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
