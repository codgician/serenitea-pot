{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.ssh;
in
{
  options.codgician.codgi.ssh.enable = lib.mkEnableOption "Enable ssh user configurations.";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      extraConfig = ''
        AddKeysToAgent yes
      '' + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
        IgnoreUnknown UseKeychain
        UseKeychain yes
        IdentityFile ~/.ssh/id_ed25519
      '';
      matchBlocks = {
        "charlotte" = {
          hostname = "charlotte.lan";
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
        "klee" = {
          hostname = "klee.lan";
          user = "codgi";
        };
        "paimon" = {
          hostname = "paimon.lan";
          user = "codgi";
        };
        "nahida" = {
          hostname = "nahida.lan";
          user = "codgi";
        };
        "raiden-ei" = {
          hostname = "raiden-ei.lan";
          user = "codgi";
        };
        "openwrt" = {
          hostname = "openwrt.lan";
          user = "root";
        };
        "nanopi" = {
          hostname = "nanopi.cdu";
          user = "root";
        };
        "lumine" = {
          hostname = "lumine.codgician.me";
          user = "codgi";
        };
      };
    };
  };
}
