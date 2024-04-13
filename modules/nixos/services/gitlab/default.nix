{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.gitlab;
  types = lib.types;
in
{
  options.codgician.services.gitlab = {
    enable = lib.mkEnableOption "Enable GitLab server.";

    statePath = lib.mkOption {
      type = types.str;
      example = "/mnt/gitlab";
      description = "Path to store GitLab state data.";
    };

    host = lib.mkOption {
      type = types.str;
      example = "gitlab.example.org";
      description = "Host name of the GitLab server.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "gitlab";
      description = lib.mdDoc "User under which GitLab runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "gitlab";
      description = lib.mdDoc "Group under which GitLab runs.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Enable PostgreSQL
      codgician.services.postgresql.enable = true;

      # GitLab configs
      services.gitlab = rec {
        enable = true;
        packages.gitlab = pkgs.gitlab;
        inherit (cfg) statePath host user group;
        https = true;
        port = 443;

        # Secrets
        initialRootPasswordFile = config.age.secrets.gitlabInitRootPasswd.path;
        secrets = {
          dbFile = config.age.secrets.gitlabDb.path;
          jwsFile = config.age.secrets.gitlabJws.path;
          otpFile = config.age.secrets.gitlabOtp.path;
          secretFile = config.age.secrets.gitlabSecret.path;
        };

        # Mail settings
        smtp = {
          enable = true;
          enableStartTLSAuto = true;
          tls = false;
          authentication = "login";
          address = "smtp.office365.com";
          port = 587;
          username = "bot@codgician.me";
          passwordFile = config.age.secrets.gitlabSmtp.path;
          domain = "codgician.me";
        };
        extraConfig.gitlab = {
          email_from = smtp.username;
          email_reply_to = smtp.username;
        };

        # OmniAuth
        extraConfig.omniauth = {
          enabled = true;
          allow_single_sign_on = [ "github" ];
          block_auto_created_users = true;
          providers = [
            {
              name = "github";
              label = "GitHub";
              app_id = "3bc605d269d8117af816";
              app_secret = { _secret = config.age.secrets.gitlabOmniAuthGitHub.path; };
              args = {
                scope = "user:email";
              };
            }
          ];
        };
      };
    }

    # Agenix secrets
    (
      let
        credFileNames = [
          "gitlabInitRootPasswd"
          "gitlabDb"
          "gitlabJws"
          "gitlabOtp"
          "gitlabSecret"
          "gitlabSmtp"
          "gitlabOmniAuthGitHub"
        ];
        credFiles = builtins.map (x: lib.codgician.secretsDir + "/${x}.age") credFileNames;
      in
      lib.codgician.mkAgenixConfigs cfg.user credFiles
    )
  ]);
}
