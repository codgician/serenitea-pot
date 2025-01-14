{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.git;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
in
{
  options.codgician.codgi.git = {
    enable = lib.mkEnableOption "Enable git user configurations.";
  };

  config = lib.mkIf cfg.enable {
    programs.git = rec {
      enable = true;
      delta.enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      userName = "codgician";
      userEmail = "15964984+codgician@users.noreply.github.com";

      extraConfig = rec {
        commit.gpgsign = true;
        tag.gpgsign = true;
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile =
            (pkgs.writeText "allowed_signers" ''
              ${userEmail} ${user.signingkey}
            '').outPath;
        };
        user.signingkey = builtins.elemAt pubKeys.users.codgi 0;
        credential.helper = lib.mkIf (pkgs.stdenvNoCC.isDarwin) "osxkeychain";
      };
    };

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings.editor = lib.getExe pkgs.vim;
    };
  };
}
