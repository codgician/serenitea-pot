{
  config,
  options,
  lib,
  ...
}:
let
  serviceName = "grafana";
  cfg = config.codgician.services.grafana;
  types = lib.types;

  scheme = if cfg.reverseProxy.https then "https" else "http";
  url = "${scheme}://${builtins.head cfg.reverseProxy.domains}";
in
{
  options.codgician.services.grafana = {
    enable = lib.mkEnableOption "Grafana";

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/grafana";
      description = "Data directory for Grafana.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://unix:/run/grafana/grafana.sock";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.grafana = {
        enable = true;
        settings = {
          database = {
            host = "/run/postgresql";
            user = "grafana";
            name = "grafana";
            type = "postgres";
          };

          security = {
            secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
            strict_transport_security = cfg.reverseProxy.enable;
            admin_password = "$__file{${config.age.secrets.grafana-admin-password.path}}";
          };

          server = {
            root_url = url;
            protocol = "socket";
            socket = "/run/grafana/grafana.sock";
            socket_mode = "0777";
            enable_gzip = true;
          };

          "auth.generic_oauth" = {
            enabled = true;
            allow_sign_up = true;
            auto_login = true;
            name = "Authelia";
            icon = "signin";
            client_id = "grafana";
            client_secret = "$__file{${config.age.secrets.grafana-oidc-secret-authelia-main.path}}";
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            empty_scopes = false;
            auth_url = "https://auth.codgician.me/api/oidc/authorization";
            token_url = "https://auth.codgician.me/api/oidc/token";
            api_url = "https://auth.codgician.me/api/oidc/userinfo";
            login_attribute_path = "preferred_username";
            groups_attribute_path = "groups";
            name_attribute_path = "name";
            email_attribute_path = "email";
            use_pkce = true;
            allow_assign_grafana_admin = true;
            # Refrain from adding trailing or, see github:grafana/grafana#106686
            role_attribute_path = builtins.concatStringsSep " || " [
              "contains(groups, 'grafana-admins') && 'GrafanaAdmin'"
              "contains(groups, 'grafana-editors') && 'Editor'"
              "contains(groups, 'grafana-viewers') && 'Viewer'"
            ];
            role_attribute_strict = true;
            skip_org_role_sync = false;
          };

          smtp = {
            enabled = true;
            host = "localhost:25";
            from_name = "Grafana";
            from_address = "bot@codgician.me";
          };

          users = {
            verify_email_enabled = true;
            default_theme = "system";
            default_language = "en-US";
            allow_sign_up = false;
            allow_org_create = false;
          };
        };
      };

      # Ensure postgres is enabled
      codgician.services.postgresql.enable = true;
      services.postgresql = {
        ensureDatabases = [ serviceName ];
        ensureUsers = [
          {
            name = serviceName;
            ensureDBOwnership = true;
          }
        ];
      };

      # Persist data when dataDir is default value
      codgician.system.impermanence.extraItems =
        lib.mkIf (cfg.dataDir == options.codgician.services.grafana.dataDir.default)
          [
            {
              type = "directory";
              path = cfg.dataDir;
              user = serviceName;
              group = serviceName;
            }
          ];

      # Agenix secrets
      codgician.system.agenix.secrets =
        lib.genAttrs
          [
            "grafana-admin-password"
            "grafana-secret-key"
            "grafana-oidc-secret-authelia-main"
          ]
          (_: {
            owner = serviceName;
          });
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
