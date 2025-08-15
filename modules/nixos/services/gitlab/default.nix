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
      services.gitlab = {
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
          activeRecordSaltFile = config.age.secrets.gitlab-active-record-salt.path;
          activeRecordPrimaryKeyFile = config.age.secrets.gitlab-active-record-primary-key.path;
          activeRecordDeterministicKeyFile = config.age.secrets.gitlab-active-record-deterministic-key.path;
        };

        # Mail settings
        smtp = {
          enable = true;
          enableStartTLSAuto = true;
          tls = false;
          authentication = "login";
          address = "127.0.0.1";
          port = 25;
          domain = "codgician.me";
        };
        extraConfig.gitlab = {
          email_from = "bot@codgician.me";
          email_reply_to = "bot@codgician.me";
        };

        # OmniAuth
        extraConfig.omniauth = {
          enabled = true;
          allow_single_sign_on = [ "openid_connect" ];
          block_auto_created_users = true;
          providers = [
            {
              name = "openid_connect";
              label = "Authelia";
              icon = "https://www.authelia.com/images/branding/logo-cropped.png";
              args = {
                name = "openid_connect";
                strategy_class = "OmniAuth::Strategies::OpenIDConnect";
                issuer = "https://auth.codgician.me";
                discovery = true;
                scope = [
                  "openid"
                  "profile"
                  "email"
                  "groups"
                ];
                client_auth_method = "basic";
                response_type = "code";
                response_mode = "query";
                uid_field = "preferred_username";
                send_scope_to_token_endpoint = true;
                pkce = true;
                client_options = {
                  identifier = "gitlab";
                  secret._secret = config.age.secrets.gitlab-oidc-secret-authelia-main.path;
                  redirect_uri = "https://${cfg.host}/users/auth/openid_connect/callback";
                };
              };
            }
          ];
        };
      };

      # Add to authorized users of postfix
      codgician.services.postfix.authorizedUsers = [ serviceName ];

      # PostgreSQL
      codgician.services.postgresql.enable = true;

      # Agenix secrets
      codgician.system.agenix.secrets =
        lib.genAttrs
          [
            "gitlab-init-root-password"
            "gitlab-db"
            "gitlab-jws"
            "gitlab-otp"
            "gitlab-secret"
            "gitlab-active-record-salt"
            "gitlab-active-record-primary-key"
            "gitlab-active-record-deterministic-key"
            "gitlab-oidc-secret-authelia-main"
          ]
          (name: {
            owner = cfg.user;
            group = cfg.group;
            mode = "0600";
          });
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
