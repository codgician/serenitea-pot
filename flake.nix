{
  description = "❄️ codgician's nix fleet";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-23.05-darwin";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , nixpkgs-darwin
    , home-manager
    , flake-utils
    , impermanence
    , darwin
    , ...
    }:
    let
      lib = nixpkgs.lib;
      processConfigurations = lib.mapAttrs (n: v: v n);

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
            {
              services.nix-daemon.enable = true;
              nix.settings.experimental-features = [ "nix-command" "flakes" ];
              networking.hostName = hostName;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs pkgs; };
            }
          ] ++ extraModules;
        };
    in
    {
      # macOS machines
      darwinConfigurations = processConfigurations {
        "Shijia-Mac" = darwinSystem "aarch64-darwin" [ ./hosts/Shijia-Mac/default.nix ];
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
