{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.11-darwin";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    impermanence.url = "github:nix-community/impermanence";

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";
    nur-xddxdd = {
      url = "github:xddxdd/nur-packages";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "darwin";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , nixpkgs-darwin
    , nixos-hardware
    , home-manager
    , nur
    , nur-xddxdd
    , agenix
    , impermanence
    , vscode-server
    , darwin
    , flake-utils
    , ...
    }:
    let
      lib = nixpkgs.lib;
      processConfigurations = lib.mapAttrs (name: value: value name);

      # Basic configs for each host
      basicConfig = system: hostName: { config, ... }: {
        nix = {
          settings = {
            auto-optimise-store = true;
            sandbox = true;
          };
          extraOptions = "experimental-features = nix-command flakes";
        };

        networking.hostName = hostName;
        environment.systemPackages = [ agenix.packages.${system}.default ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Include age secrets by name
      secretsDir = builtins.toString ./secrets;
      ageSecrets = builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj));

      # Common configurations for macOS systems
      darwinSystem = system: extraModules: hostName:
        let
          pkgs = import nixpkgs-darwin {
            inherit system;
            config.allowUnfree = true;
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit lib pkgs inputs self darwin; };
          modules = [
            home-manager.darwinModules.home-manager
            agenix.darwinModules.default

            (basicConfig system hostName)

            ({ config, ... }: {
              services.nix-daemon.enable = true;
            })
          ] ++ extraModules;
        };

      # Common configurations for NixOS systems
      nixosSystem = system: extraModules: hostName:
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
          specialArgs = { inherit lib pkgs inputs self impermanence; };
          modules = [
            nur.nixosModules.nur
            ({ config, ... }: {
              nix.settings.substituters = [ config.nur.repos.xddxdd._meta.url ];
              nix.settings.trusted-public-keys = [ config.nur.repos.xddxdd._meta.publicKey ];
            })

            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            vscode-server.nixosModules.default

            (basicConfig system hostName)

            ({ config, ... }: {
              # Set flake for auto upgrade
              system.autoUpgrade.flake = "github:codgician/nix-fleet";

              age.secrets = ageSecrets {
                "codgiPassword" = {
                  mode = "600";
                  owner = "codgi";
                };
                "bmcPassword" = {
                  mode = "600";
                  owner = "bmc";
                };
              };
            })
          ] ++ extraModules;
        };
    in
    {
      # macOS machines
      darwinConfigurations = processConfigurations {
        "Shijia-Mac" = darwinSystem "aarch64-darwin" [ ./hosts/mac/default.nix ];
        "MacRun" = darwinSystem "x86_64-darwin" [ ./hosts/runners/macrun.nix ];
      };

      # NixOS machines
      nixosConfigurations = processConfigurations {
        "mona" = nixosSystem "x86_64-linux" [ ./hosts/mona/default.nix ];
        "Shijia-X1" = nixosSystem "x86_64-linux" [
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-yoga
          ./hosts/x1/default.nix
        ];
      };
    } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      agenixCli = agenix.packages.${system}.default;
    in
    {
      # Development shell
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [ rnix-lsp agenixCli ];
      };

      # Formatter
      formatter = pkgs.nixpkgs-fmt;
    });
}
