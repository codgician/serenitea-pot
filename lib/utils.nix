{
  lib,
  nixpkgs,
  inputs,
  outputs,
  ...
}:
let
  inherit (lib.codgician) stable;
in
rec {
  # Package overlays
  overlays =
    [
      (self: super: { inherit lib; })
      inputs.nur.overlays.default
      inputs.nix-vscode-extensions.overlays.default
      inputs.mlnx-ofed-nixos.overlays.default
    ]
    ++ (builtins.map (x: import x { inherit inputs lib; }) (
      with lib.codgician; getFolderPaths overlaysDir
    ));

  # Make package universe
  mkPkgs =
    system:
    (import nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
      flake.source = nixpkgs.outPath;
    });

  # Make home-manager module
  mkHomeManagerModules =
    with inputs;
    modulesName: sharedModules:
    let
      homeManager = if stable then home-manager else home-manager-unstable;
    in
    [
      (homeManager.${modulesName}.home-manager)
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          inherit sharedModules;
        };
      }
    ];

  # All Darwin modules for building system
  mkDarwinModules =
    with inputs;
    (mkHomeManagerModules "darwinModules" [
      # Home Manager modules
    ])
    ++ [
      # Darwin modules
      outputs.modules.darwin
      agenix.darwinModules.default
    ];

  # All NixOS modules for building system
  mkNixosModules =
    with inputs;
    (mkHomeManagerModules "nixosModules" [
      # Home Manager modules
      plasma-manager.homeManagerModules.plasma-manager
    ])
    ++ [
      # NixOS modules
      outputs.modules.nixos
      impermanence.nixosModules.impermanence
      disko.nixosModules.disko
      agenix.nixosModules.default
      lanzaboote.nixosModules.lanzaboote
      nixos-generators.nixosModules.all-formats
      nixos-wsl.nixosModules.wsl
      nixvirt.nixosModules.default
      mlnx-ofed-nixos.nixosModules.default
      vscode-server.nixosModules.default
      proxmox-nixos.nixosModules.proxmox-ve
      (
        { system, ... }:
        {
          nixpkgs.overlays = [ proxmox-nixos.overlays.${system} ];
        }
      )
    ];

  # Base configs for all platforms
  mkBaseConfig =
    system: hostName:
    { lib, ... }:
    {
      networking.hostName = hostName;
      nixpkgs = {
        config.allowUnfree = true;
        inherit (lib.codgician) overlays;
      };
    };

  # Common configurations for macOS systems
  mkDarwinSystem =
    {
      hostName,
      modules ? [ ],
      system,
      nix-darwin ? inputs."${if stable then "darwin" else "darwin-unstable"}",
    }:
    nix-darwin.lib.darwinSystem {
      inherit system lib;
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          system
          ;
      };
      modules =
        lib.codgician.mkDarwinModules
        ++ modules
        ++ [
          (mkBaseConfig system hostName)
        ];
    };

  # Common configurations for NixOS systems
  mkNixosSystem =
    {
      hostName,
      modules ? [ ],
      system,
      nixpkgs ? inputs."${if stable then "nixpkgs" else "nixpkgs-unstable"}",
    }:
    nixpkgs.lib.nixosSystem {
      inherit system lib;
      specialArgs = {
        inherit
          inputs
          outputs
          lib
          system
          ;
      };
      modules =
        lib.codgician.mkNixosModules
        ++ modules
        ++ [
          (mkBaseConfig system hostName)
        ];
    };

  # List of supported systems
  darwinSystems = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];
  linuxSystems = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  isDarwinSystem = lib.hasSuffix "-darwin";
  isLinuxSystem = lib.hasSuffix "-linux";
  allSystems = darwinSystems ++ linuxSystems;

  # Generate attribution set for specified systems
  forSystems = systems: func: lib.genAttrs systems (system: func (mkPkgs system));
  forAllSystems = forSystems allSystems;
  forDarwinSystems = forSystems darwinSystems;
  forLinuxSystems = forSystems linuxSystems;
}
