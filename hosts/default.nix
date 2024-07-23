{ inputs, lib, mkLib, mkPkgs, mkDarwinModules, mkNixosModules, ... }:
let
  # Base configs for all platforms
  mkBaseConfig = system: hostName: { config, ... }: {
    networking.hostName = hostName;
    nix = {
      extraOptions = "experimental-features = nix-command flakes repl-flake";
      settings = {
        extra-nix-path = "nixpkgs=flake:nixpkgs";
        sandbox = true;
        auto-optimise-store = true;
      };
    };
    nixpkgs.config.allowUnfree = true;
  };

  # Common configurations for macOS systems
  mkDarwinSystem =
    { hostName
    , modules ? [ ]
    , system
    , stable ? true
    }:
    let
      nixpkgs = if stable then inputs.nixpkgs-darwin else inputs.nixpkgs-nixos-unstable;
      pkgs = mkPkgs nixpkgs system;
      lib = mkLib nixpkgs;
    in
    inputs.darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = (mkDarwinModules stable) ++ modules ++ [
        (mkBaseConfig system hostName)
        ({ config, ... }: {
          services.nix-daemon.enable = true;
        })
      ];
    };

  # Common configurations for NixOS systems
  mkNixosSystem =
    { hostName
    , modules ? [ ]
    , system
    , stable ? true
    }:
    let
      nixpkgs = if stable then inputs.nixpkgs else inputs.nixpkgs-nixos-unstable;
      pkgs = mkPkgs nixpkgs system;
      lib = mkLib nixpkgs;
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = (mkNixosModules stable) ++ modules ++ [
        (mkBaseConfig system hostName)
        ({ config, ... }: {
          # Set flake for auto upgrade
          system.autoUpgrade = {
            flake = "github:codgician/serenitea-pot";
            flags = [ "--refresh" "--no-write-lock-file" "-L" ];
          };
        })
      ];
    };

  hosts = builtins.map (x: (import ./${x}) // { hostName = x; }) (lib.codgician.getFolderNames ./.);
  hostsToAttr = builder: hosts: builtins.listToAttrs (builtins.map (host: { name = host.hostName; value = builder host; }) hosts);
in
rec {
  darwinHosts = builtins.filter (x: lib.hasSuffix "-darwin" x.system) hosts;
  nixosHosts = builtins.filter (x: lib.hasSuffix "-linux" x.system) hosts;

  darwinConfigurations = hostsToAttr mkDarwinSystem darwinHosts;
  nixosConfigurations = hostsToAttr mkNixosSystem nixosHosts;
}
