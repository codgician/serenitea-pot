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

  # Identity submodule type
  identityType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Git user name for this identity.";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Git user email for this identity.";
      };
      signingkey = lib.mkOption {
        type = lib.types.str;
        description = "SSH signing key for this identity.";
      };
    };
  };

  # Get default identity
  defaultIdentity = cfg.identities.${cfg.defaultIdentity};

  # Generate includes from directoryIdentities
  directoryIncludes = lib.mapAttrsToList (dir: identityName: {
    condition = "gitdir:${dir}";
    contents.user = cfg.identities.${identityName};
  }) cfg.directoryIdentities;
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

    identities = lib.mkOption {
      type = lib.types.attrsOf identityType;
      default = {
        personal = {
          name = "codgician";
          email = "15964984+codgician@users.noreply.github.com";
          signingkey = builtins.elemAt pubKeys.users.codgi 0;
        };
        work = {
          name = "Shijia Zhang";
          email = "shijiazhang@microsoft.com";
          signingkey = builtins.elemAt pubKeys.users.shijiazhang 0;
        };
      };
      description = "Named git identities with name, email, and signing key.";
      example = lib.literalExpression ''
        {
          personal = {
            name = "Personal Name";
            email = "personal@example.com";
            signingkey = "ssh-ed25519 AAAA...";
          };
          work = {
            name = "Work Name";
            email = "work@company.com";
            signingkey = "ssh-ed25519 BBBB...";
          };
        }
      '';
    };

    defaultIdentity = lib.mkOption {
      type = lib.types.str;
      default = "personal";
      description = "Name of the default identity to use.";
    };

    directoryIdentities = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Map directories to identity names. Uses git includeIf gitdir conditions.
        Directory paths should end with a trailing slash.
      '';
      example = lib.literalExpression ''
        {
          "/code/" = "work";
          "~/projects/oss/" = "personal";
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.delta.enable = true;
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      # Directory-based identity includes
      includes = directoryIncludes;

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
          inherit (defaultIdentity) name email signingkey;
        };
      };
    };

    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = false; # Use GCM instead for multi-account support
      settings.editor = lib.getExe pkgs.vim;
    };
  };
}
