{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.ssh;
in
{
  options.codgician.codgi.ssh.enable = lib.mkEnableOption "Enable ssh user configurations.";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
      extraConfig = lib.optionalString pkgs.stdenvNoCC.isDarwin ''
        IgnoreUnknown UseKeychain
        UseKeychain yes
        IdentityFile ~/.ssh/id_ed25519
      '';
      matchBlocks = {
        "fischl" = {
          hostname = "fischl.lan";
          user = "codgi";
        };
        "focalors" = {
          hostname = "focalors.lan";
          user = "codgi";
        };
        "furina" = {
          hostname = "furina.lan";
          user = "codgi";
        };
        "lumine" = {
          hostname = "lumine.codgician.me";
          user = "codgi";
        };
        "nahida" = {
          hostname = "nahida.lan";
          user = "codgi";
        };
        "nanopi" = {
          hostname = "nanopi.cdu";
          user = "root";
        };
        "openwrt" = {
          hostname = "openwrt.lan";
          user = "root";
        };
        "paimon" = {
          hostname = "paimon.lan";
          user = "codgi";
        };
        "raiden-ei" = {
          hostname = "raiden-ei.lan";
          user = "codgi";
        };
        "sigewinne" = {
          hostname = "sigewinne.lan";
          user = "codgi";
        };
      };
    };
  };
}
