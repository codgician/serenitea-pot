{ inputs, lib, mkLib, mkPkgs, darwinModules, nixosModules, ... }:
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
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };

  # Common configurations for macOS systems
  darwinSystem =
    { hostName
    , modules ? [ ]
    , system
    , nixpkgs ? inputs.nixpkgs-darwin
    , home-manager ? inputs.home-manager
    }:
    let
      pkgs = mkPkgs nixpkgs system;
      lib = mkLib nixpkgs;
    in
    inputs.darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = with inputs; [
        darwinModules.default
        (mkBaseConfig system hostName)

        home-manager.darwinModules.home-manager
        agenix.darwinModules.default

        ({ config, ... }: {
          services.nix-daemon.enable = true;
        })
      ] ++ modules;
    };

  # Common configurations for NixOS systems
  nixosSystem =
    { hostName
    , modules ? [ ]
    , system
    , nixpkgs ? inputs.nixpkgs
    , home-manager ? inputs.home-manager
    }:
    let
      pkgs = mkPkgs nixpkgs system;
      lib = mkLib nixpkgs;
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs lib system; };
      modules = with inputs; [
        nixosModules.default
        (mkBaseConfig system hostName)

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
          system.autoUpgrade.flake = "github:codgician/serenitea-pot";
        })
      ] ++ modules;
    };

  hosts = builtins.map (x: (import ./${x} { inherit inputs; }) // { hostName = x; }) (lib.codgician.getFolderNames ./.);
  darwinHosts = builtins.filter (x: lib.hasSuffix "-darwin" x.system) hosts;
  nixosHosts = builtins.filter (x: lib.hasSuffix "-linux" x.system) hosts;
  hostsToAttr = builder: hosts: builtins.listToAttrs (builtins.map (host: { name = host.hostName; value = builder host; }) hosts);
in
{
  darwinConfigurations = hostsToAttr darwinSystem darwinHosts;
  nixosConfigurations = hostsToAttr nixosSystem nixosHosts;
}
