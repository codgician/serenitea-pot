{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.ssh;
in
{
  options.codgician.codgi.ssh.enable = lib.mkEnableOption "Ssh user configurations.";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      extraConfig = ''
        IdentityFile ~/.ssh/id_ed25519
      ''
      + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
        IgnoreUnknown UseKeychain
        UseKeychain yes
      '';
      matchBlocks = {
        "*" = {
          addKeysToAgent = "yes";
        };
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
        "lumidouce" = {
          hostname = "lumidouce.lan";
          user = "root";
        };
        "qiaoying" = {
          hostname = "qiaoying.cdu";
          user = "root";
        };
        "nahida" = {
          hostname = "nahida.lan";
          user = "codgi";
        };
        "paimon" = {
          hostname = "paimon.lan";
          user = "codgi";
        };
        "raiden-ei" = {
          hostname = "raiden-ei.lan";
          user = "codgi";
        };
        "sandrone" = {
          hostname = "sandrone.lan";
          user = "codgi";
        };
        "xianyun" = {
          hostname = "xianyun.codgician.me";
          user = "codgi";
        };
      };
    };
  };
}
