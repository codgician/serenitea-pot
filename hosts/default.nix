{ inputs, mkLib, mkDarwinModules, mkNixosModules, overlays ? [ ], ... }:
let
  # Base configs for all platforms
  mkBaseConfig = system: hostName: { config, ... }: {
    networking.hostName = hostName;
    nixpkgs = {
      config.allowUnfree = true;
      inherit overlays;
    };
  };

  # Common configurations for macOS systems
  mkDarwinSystem =
    { hostName
    , modules ? [ ]
    , system
    , stable ? true
    }:
    let
      nixpkgs = if stable then inputs.nixpkgs else inputs.nixpkgs-nixos-unstable;
      lib = mkLib nixpkgs;
    in
    inputs.darwin.lib.darwinSystem {
      inherit system lib;
      specialArgs = { inherit inputs lib system; };
      modules = (mkDarwinModules stable) ++ modules ++ [
        (mkBaseConfig system hostName)
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
      lib = mkLib nixpkgs;
    in
    nixpkgs.lib.nixosSystem {
      inherit system lib;
      specialArgs = { inherit inputs lib system; };
      modules = (mkNixosModules stable) ++ modules ++ [
        (mkBaseConfig system hostName)
      ];
    };

  lib = mkLib inputs.nixpkgs;
  hosts = builtins.map (x: (import ./${x}) // { hostName = x; }) (lib.codgician.getFolderNames ./.);
  hostsToAttr = builder: hosts: builtins.listToAttrs (builtins.map (host: { name = host.hostName; value = builder host; }) hosts);
in
rec {
  darwinHosts = builtins.filter (x: lib.hasSuffix "-darwin" x.system) hosts;
  nixosHosts = builtins.filter (x: lib.hasSuffix "-linux" x.system) hosts;

  darwinConfigurations = hostsToAttr mkDarwinSystem darwinHosts;
  nixosConfigurations = hostsToAttr mkNixosSystem nixosHosts;
}
