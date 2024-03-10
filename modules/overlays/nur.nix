{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.overlays.nur.xddxdd;
in
{
  options.codgician.overlays.nur.xddxdd = {
    enable = lib.mkEnableOption "Enable xddxdd's NUR.";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        nur = import inputs.nur {
          nurpkgs = prev;
          pkgs = prev;
          repoOverrides = { xddxdd = import inputs.nur-xddxdd { pkgs = prev; }; };
        };
      })
    ];

    # Use xddxdd's binary cache
    nix.settings = {
      substituters = [ "https://xddxdd.cachix.org" ];
      trusted-public-keys = [ "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" ];
    };
  };
}
