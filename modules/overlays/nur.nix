{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.overlays.nur;
in
{
  options.codgician.overlays.nur = {
    xddxdd = {
      enable = lib.mkEnableOption "Enable xddxdd's NUR.";
    };
  };

  config = {
    nixpkgs.overlays = [
      (lib.mkIf cfg.xddxdd.enable (final: prev: {
        nur = import inputs.nur {
          nurpkgs = prev;
          pkgs = prev;
          repoOverrides = { xddxdd = import inputs.nur-xddxdd { pkgs = prev; }; };
        };
      }))
    ];

    # Use xddxdd's binary cache
    nix.settings = lib.mkMerge [
      (lib.mkIf cfg.xddxdd.enable {
        substituters = [ "https://xddxdd.cachix.org" ];
        trusted-public-keys = [ "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" ];
      })
    ];
  };
}
