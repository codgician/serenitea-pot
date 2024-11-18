{ config, lib, inputs, ... }:
let
  cfg = config.codgician.nix;
  flakePath = lib.codgician.rootDir + "/flake.nix";
  substituters = (import flakePath).nixConfig.extra-substituters;
  trusted-public-keys = (import flakePath).nixConfig.extra-trusted-public-keys;
in
{
  options.codgician.nix = {
    nurs.xddxdd.enable = lib.mkEnableOption "Enable xddxdd's NUR.";
  };

  config = {
    nixpkgs.overlays = [
      (lib.mkIf cfg.nurs.xddxdd.enable (self: super: {
        nur = import inputs.nur {
          nurpkgs = super;
          pkgs = super;
          repoOverrides = { xddxdd = import inputs.nur-xddxdd { pkgs = super; }; };
        };
      }))
    ];

    nix = {
      # Nix garbage collection
      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };

      extraOptions = ''
        experimental-features = nix-command flakes
        accept-flake-config = true
      '';
      optimise.automatic = true;
      settings = lib.mkMerge [
        {
          inherit substituters trusted-public-keys;
          extra-nix-path = "nixpkgs=flake:nixpkgs";
        }

        # Use xddxdd's binary cache
        (lib.mkIf cfg.nurs.xddxdd.enable {
          substituters = [ "https://xddxdd.cachix.org" ];
          trusted-public-keys = [ "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" ];
        })
      ];
    };
  };
}
