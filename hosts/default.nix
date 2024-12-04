{ inputs, outputs, mkLib, mkDarwinModules, mkNixosModules, ... }:
let
  # Base configs for all platforms
  mkBaseConfig = system: hostName: { config, lib, ... }: {
    networking.hostName = hostName;
    nixpkgs = {
      config.allowUnfree = true;
      inherit (lib.codgician) overlays;
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
      specialArgs = { inherit inputs outputs lib system; };
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
      specialArgs = { inherit inputs outputs lib system; };
      modules = (mkNixosModules stable) ++ modules ++ [
        (mkBaseConfig system hostName)
      ];
    };

  lib = mkLib inputs.nixpkgs;
  hosts = lib.pipe (lib.codgician.getFolderNames ./.) [
    (builtins.map (x: (import ./${x}) // { hostName = x; }))
    (builtins.filter (x: !x?enable || x.enable))
  ];
  hostsToAttr = builder: hosts: lib.pipe hosts [
    (builtins.map (host: { name = host.hostName; value = builder host; }))
    builtins.listToAttrs
  ];
in
rec {
  darwinHosts = builtins.filter (x: lib.codgician.isDarwinSystem x.system) hosts;
  nixosHosts = builtins.filter (x: lib.codgician.isLinuxSystem x.system) hosts;

  darwinConfigurations = hostsToAttr mkDarwinSystem darwinHosts;
  nixosConfigurations = hostsToAttr mkNixosSystem nixosHosts;
}
