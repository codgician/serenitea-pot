{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.nix;
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
      package = pkgs.lix;
      settings = lib.mkMerge [
        {
          substituters = [
            "https://nix-community.cachix.org"
            "https://cache.lix.systems"
            "https://cache.saumon.network/proxmox-nixos"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
            "proxmox-nixos:nveXDuVVhFDRFx8Dn19f1WDEaNRJjPrF2CPD2D+m1ys="
          ];
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
