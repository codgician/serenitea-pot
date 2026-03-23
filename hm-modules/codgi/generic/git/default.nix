{
  config,
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.git;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
  isDarwin = pkgs.stdenvNoCC.isDarwin;
in
{
  options.codgician.codgi.git = {
    enable = lib.mkEnableOption "Git user configurations.";

    useGitCredentialManager = lib.mkOption {
      type = lib.types.bool;
      default = osConfig.codgician.system.capabilities.hasSecretStorage or false;
      description = ''
        Use Git Credential Manager (GCM) for credential storage.
        Supports Azure DevOps, GitHub, GitLab, and Bitbucket.
        Requires a secret storage backend (GNOME Keyring, KDE Wallet, or macOS Keychain).
        Defaults to true when a secret storage backend is available.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.delta.enable = true;
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      settings = rec {
        credential = lib.mkMerge [
          # GCM for hosts with secret storage
          (lib.mkIf cfg.useGitCredentialManager {
            helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
            credentialStore = lib.mkIf (!isDarwin) "secretservice";
          })
          # Fallback to osxkeychain on Darwin without GCM
          (lib.mkIf (isDarwin && !cfg.useGitCredentialManager) {
            helper = "osxkeychain";
          })
        ];

        # Azure DevOps requires useHttpPath to determine organization from URL
        "credential \"https://dev.azure.com\"".useHttpPath = true;

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
