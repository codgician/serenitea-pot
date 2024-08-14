{ config, lib, inputs, ... }:
let
  cfg = config.codgician.nur;
in
{
  options.codgician.nur = {
    xddxdd = {
      enable = lib.mkEnableOption "Enable xddxdd's NUR.";
    };
  };

  config = {
    nixpkgs.overlays = [
      (lib.mkIf cfg.xddxdd.enable (self: super: {
        nur = import inputs.nur {
          nurpkgs = super;
          pkgs = super;
          repoOverrides = { xddxdd = import inputs.nur-xddxdd { pkgs = super; }; };
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
