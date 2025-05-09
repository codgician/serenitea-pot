{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "gitlab";
  cfg = config.codgician.services.gitlab;
  types = lib.types;
in
{
  options.codgician.services.gitlab = {
    enable = lib.mkEnableOption "GitLab server.";

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
      default = serviceName;
      description = "User under which GitLab runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which GitLab runs.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultDomains = [ cfg.host ];
      defaultDomainsText = "[ config.codgician.services.gitlab.host ]";
      defaultProxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
    };
  };

  config = lib.mkMerge [
    # GitLab configurations
    (lib.mkIf cfg.enable {
      services.gitlab = rec {
        enable = true;
        packages.gitlab = pkgs.gitlab;
        inherit (cfg)
          statePath
          host
          user
          group
          ;
        https = true;
        port = 443;

        # Secrets
        initialRootPasswordFile = config.age.secrets.gitlab-init-root-password.path;
        secrets = {
          dbFile = config.age.secrets.gitlab-db.path;
          jwsFile = config.age.secrets.gitlab-jws.path;
          otpFile = config.age.secrets.gitlab-otp.path;
          secretFile = config.age.secrets.gitlab-secret.path;
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
          passwordFile = config.age.secrets.gitlab-smtp.path;
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
              app_secret = {
                _secret = config.age.secrets.gitlab-omniauth-github.path;
              };
              args = {
                scope = "user:email";
              };
            }
          ];
        };
      };

      # PostgreSQL
      codgician.services.postgresql.enable = true;
    })

    # Agenix secrets
    (lib.mkIf cfg.enable (
      with lib.codgician;
      mkAgenixConfigs { owner = cfg.user; } (
        builtins.map getAgeSecretPathFromName [
          "gitlab-init-root-password"
          "gitlab-db"
          "gitlab-jws"
          "gitlab-otp"
          "gitlab-secret"
          "gitlab-smtp"
          "gitlab-omniauth-github"
        ]
      )
    ))

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
