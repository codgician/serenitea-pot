{
  description = "❄️ Home to codgician's nix-managed device profiles";

  nixConfig = {
    allow-import-from-derivation = "true";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://codgician.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://cache.garnix.io"
      "https://mlnx-ofed-nixos.cachix.org"
      "https://cache.saumon.network/proxmox-nixos"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "codgician.cachix.org-1:v4RtwkbJZJwfDxH5hac1lHehIX6JoSL726vk1ZctN8Y="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "mlnx-ofed-nixos.cachix.org-1:jL/cqleOzhPw87etuHMeIIdAgFDKX8WnTBYMSBx3toI="
      "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";

    mlnx-ofed-nixos = {
      url = "github:codgician/mlnx-ofed-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    proxmox-nixos = {
      url = "github:codgician/proxmox-nixos/pve-8-latest";
      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        flake-compat.follows = "flake-compat";
        utils.follows = "flake-utils";
      };
    };

    mobile-nixos = {
      url = "github:codgician/mobile-nixos/fix-depmod";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin-unstable = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    impermanence.url = "github:nix-community/impermanence";

    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        darwin.follows = "darwin";
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        flake-parts.follows = "flake-parts";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
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
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      # Extending lib
      mkLib =
        stable:
        (import ./lib {
          inherit inputs stable;
          outputs = self;
        });
      lib = mkLib true;
      libUnstable = mkLib false;
    in
    {
      # System configurations
      inherit
        (import ./hosts {
          inherit inputs;
          outputs = self;
        })
        darwinConfigurations
        nixosConfigurations
        ;

      # Modules
      modules = import ./modules { inherit lib; };

      # Export custom library
      inherit lib libUnstable;

      # Apps: `nix run .#appName`
      apps = (
        import ./apps {
          inherit lib inputs;
          outputs = self;
        }
      );

      # Development shell: `nix develop .#name`
      devShells = lib.codgician.forAllSystems (
        pkgs:
        import ./shells {
          inherit lib pkgs inputs;
          outputs = self;
        }
      );

      # Formatter: `nix fmt`
      formatter = lib.codgician.forAllSystems (
        pkgs:
        pkgs.writeShellApplication {
          name = "formatter";
          runtimeInputs = with pkgs; [
            treefmt
            nixfmt-rfc-style
            mdformat
            yamlfmt
          ];
          text = lib.getExe pkgs.treefmt;
        }
      );

      # Packages: `nix build .#pkgName`
      packages = lib.codgician.forAllSystems (
        pkgs:
        import ./packages {
          inherit lib pkgs inputs;
          outputs = self;
        }
      );
    };
}
