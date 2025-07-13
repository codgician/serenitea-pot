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
            root_url = lib.mkIf cfg.reverseProxy.enable "https://${builtins.head cfg.reverseProxy.domains}";
            protocol = "socket";
            socket = "/run/grafana/grafana.sock";
            socket_mode = "0660";
            enable_gzip = true;
          };

          smtp = rec {
            enabled = true;
            user = "bot@codgician.me";
            password = "$__file{${config.age.secrets.grafana-smtp.path}}";
            host = "smtp.office365.com:587";
            startTLS_policy = "MandatoryStartTLS";
            from_name = "Grafana";
            from_address = user;
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
            "grafana-smtp"
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
