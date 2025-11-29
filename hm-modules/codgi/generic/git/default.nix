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
    enable = lib.mkEnableOption "Git user configurations.";
  };

  config = lib.mkIf cfg.enable {
    programs.delta.enable = true;
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      settings = rec {
        credential.helper = lib.mkIf (pkgs.stdenvNoCC.isDarwin) "osxkeychain";
        commit.gpgsign = true;
        tag.gpgsign = true;
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile =
            (pkgs.writeText "allowed_signers" ''
              ${user.name} ${user.signingkey}
            '').outPath;
        };
        user = {
          name = "codgician";
          email = "15964984+codgician@users.noreply.github.com";
          signingkey = builtins.elemAt pubKeys.users.codgi 0;
        };
      };
    };

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings.editor = lib.getExe pkgs.vim;
    };
  };
}
