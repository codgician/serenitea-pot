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
            "https://cache.nixos.org/"
          ];
          trusted-public-keys = [
            "binarycache.example.com-1:dsafdafDFW123fdasfa123124FADSAD"
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
