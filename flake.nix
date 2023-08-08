{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    impermanence.url = "github:nix-community/impermanence";

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
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
    , home-manager
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
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        networking.hostName = hostName;
        environment.systemPackages = [ agenix.packages.${system}.default ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
        };
      };

      # Include age secrets by name
      secretsDir = "${ builtins.toString ../../secrets }";
      ageSecrets = x: builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj)) x;

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
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit lib pkgs inputs self impermanence; };
          modules = [
            impermanence.nixosModules.impermanence
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            vscode-server.nixosModules.default

            (basicConfig system hostName)

            ({ config, ... }: {
              age.secrets = ageSecrets {
                "codgiPassword" = {
                  mode = "700";
                  owner = "codgi";
                };
              };
            })
          ] ++ extraModules;
        };
    in
    {
      # macOS machines
      darwinConfigurations = processConfigurations {
        "Shijia-Mac" = darwinSystem "aarch64-darwin" [ ./hosts/shijia-mac/default.nix ];
      };

      # NixOS machines
      nixosConfigurations = processConfigurations {
        "pilot" = nixosSystem "x86_64-linux" [ ./hosts/pilot/default.nix ];
      };
    } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Development shell
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [ rnix-lsp ];
      };

      # Formatter
      formatter = pkgs.nixpkgs-fmt;
    });
}
