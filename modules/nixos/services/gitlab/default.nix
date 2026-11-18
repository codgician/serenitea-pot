{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.gitlab;
  inherit (lib.codgician) inventory published;
  svc = published.services.gitlab;
in
{
  options.codgician.services.gitlab = {
    enable = lib.codgician.mkPublishedEnableOption config "gitlab";

    statePath = lib.mkOption {
      type = lib.types.str;
      example = "/mnt/gitlab";
      description = "Path to store GitLab state data.";
    };
  };

  config = lib.mkIf cfg.enable {
    codgician.services.nginx.reverseProxies.gitlab.proxyPass =
      "http://unix:/run/gitlab/gitlab-workhorse.socket";

    services.gitlab = {
      enable = true;
      packages.gitlab = pkgs.gitlab;
      inherit (cfg) statePath;
      host = svc.domain;
      https = true;
      port = 443;

      # Secrets
      initialRootPasswordFile = config.codgician.secrets.files.gitlab-init-root-password.path;
      secrets = {
        dbFile = config.codgician.secrets.files.gitlab-db.path;
        jwsFile = config.codgician.secrets.files.gitlab-jws.path;
        otpFile = config.codgician.secrets.files.gitlab-otp.path;
        secretFile = config.codgician.secrets.files.gitlab-secret.path;
        activeRecordSaltFile = config.codgician.secrets.files.gitlab-active-record-salt.path;
        activeRecordPrimaryKeyFile = config.codgician.secrets.files.gitlab-active-record-primary-key.path;
        activeRecordDeterministicKeyFile =
          config.codgician.secrets.files.gitlab-active-record-deterministic-key.path;
      };

      # Mail settings
      smtp = {
        enable = true;
        enableStartTLSAuto = true;
        tls = false;
        authentication = "login";
        address = "127.0.0.1";
        port = 25;
        domain = inventory.zone;
      };

      extraConfig = {
        gitlab = {
          email_from = inventory.mail;
          email_reply_to = inventory.mail;

          # Disable telemetry
          include_optional_metrics_in_service_ping = false;
          usage_ping_enabled = false;
          usage_ping_generation_enabled = false;
        };

        pages = {
          enabled = false;
          port = 443;
          https = true;
          external_https = [ "127.0.0.1:443" ];
        };

        # OmniAuth
        omniauth = {
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
                issuer = published.autheliaUrl;
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
                  secret._secret = config.codgician.secrets.files.gitlab-oidc-secret-authelia-main.path;
                  redirect_uri = "https://${svc.domain}/users/auth/openid_connect/callback";
                };
              };
            }
          ];
        };
      };
    };

    # Add to authorized users of postfix
    codgician.services.postfix.authorizedUsers = [ "gitlab" ];

    # PostgreSQL
    codgician.services.postgresql.enable = true;

    # sops secrets
    codgician.secrets.files =
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
          owner = "gitlab";
          group = "gitlab";
          mode = "0600";
        });
  };
}
