{
  lib,
  nixpkgs,
  inputs,
  outputs,
  ...
}:
rec {
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

  # Global instantiation of unstable pkgs
  unstablePkgsMap = lib.genAttrs allSystems (
    system:
    import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = getCommonOverlays system;
    }
  );

  # Get package overlays
  getCommonOverlays =
    system:
    [
      inputs.nur.overlays.default
      inputs.nix-vscode-extensions.overlays.default
      inputs.mlnx-ofed-nixos.overlays.default
    ]
    ++ (lib.optional (isLinuxSystem system) inputs.proxmox-nixos.overlays.${system});

  getOverlays =
    system:
    (getCommonOverlays system)
    ++ [
      (final: prev: {
        unstable = unstablePkgsMap.${system};
        inherit lib;
      })
    ]
    ++ (builtins.map (
      x:
      import x {
        inherit
          inputs
          lib
          system
          outputs
          ;
      }
    ) (with lib.codgician; getFolderPaths overlaysDir));

  # Make package universe
  mkPkgs =
    system:
    (import nixpkgs {
      inherit system;
      overlays = getOverlays system;
      config.allowUnfree = true;
      flake.source = nixpkgs.outPath;
    });

  # Make home-manager module
  mkHomeManagerModules =
    {
      home-manager ? inputs.home-manager,
      modulesName,
      sharedModules,
    }:
    [
      (home-manager.${modulesName}.home-manager)
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
    {
      home-manager ? inputs.home-manager,
    }:
    with inputs;
    (mkHomeManagerModules {
      inherit home-manager;
      modulesName = "darwinModules";
      sharedModules = [
        # Home Manager modules
      ];
    })
    ++ [
      # Darwin modules
      outputs.modules.darwin
      agenix.darwinModules.default
    ];

  # All NixOS modules for building system
  mkNixosModules =
    {
      home-manager ? inputs.home-manager,
    }:
    with inputs;
    (mkHomeManagerModules {
      inherit home-manager;
      modulesName = "nixosModules";
      sharedModules = [
        # Home Manager modules
        plasma-manager.homeModules.plasma-manager
      ];
    })
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
    ];

  # Base configs for all platforms
  mkBaseConfig =
    system: hostName:
    { ... }:
    {
      networking.hostName = hostName;
      nixpkgs = {
        config.allowUnfree = true;
        overlays = getOverlays system;
      };
    };

  # Common configurations for macOS systems
  mkDarwinSystem =
    {
      hostName,
      modules ? [ ],
      system,
      stable ? true,
      nix-darwin ? if stable then inputs.darwin else inputs.darwin-unstable,
      home-manager ? if stable then inputs.home-manager else inputs.home-manager-unstable,
      ...
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
        (lib.codgician.mkDarwinModules { inherit home-manager; })
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
      stable ? true,
      nixpkgs ? if stable then inputs.nixpkgs else inputs.nixpkgs-unstable,
      home-manager ? if stable then inputs.home-manager else inputs.home-manager-unstable,
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
        (lib.codgician.mkNixosModules { inherit home-manager; })
        ++ modules
        ++ [
          (mkBaseConfig system hostName)
        ];
    };

  # Generate attribution set for specified systems
  forSystems = systems: func: lib.genAttrs systems (system: func (mkPkgs system));
  forAllSystems = forSystems allSystems;
  forDarwinSystems = forSystems darwinSystems;
  forLinuxSystems = forSystems linuxSystems;
}
