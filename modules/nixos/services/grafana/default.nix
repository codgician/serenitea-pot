{
  config,
  options,
  lib,
  ...
}:
let
  cfg = config.codgician.services.grafana;
  systemCfg = config.codgician.system;
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
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for Grafana";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://unix:/run/grafana/grafana.sock";
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
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
        ensureDatabases = [ "grafana" ];
        ensureUsers = [
          {
            name = "grafana";
            ensureDBOwnership = true;
          }
        ];
      };

      # Persist data when dataDir is default value
      environment = lib.optionalAttrs (systemCfg ? impermanence) {
        persistence.${systemCfg.impermanence.path}.directories =
          lib.mkIf (cfg.dataDir == options.codgician.services.grafana.dataDir.default)
            [
              {
                directory = cfg.dataDir;
                mode = "0750";
                user = "grafana";
                group = "grafana";
              }
            ];
      };
    })

    # Agenix secrets
    (lib.mkIf cfg.enable (
      with lib.codgician;
      mkAgenixConfigs { owner = "grafana"; } (
        builtins.map getAgeSecretPathFromName [
          "grafana-admin-password"
          "grafana-secret-key"
          "grafana-smtp"
        ]
      )
    ))

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.grafana = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };

      # Add nginx to grafana group if served locally
      users.users.nginx.extraGroups = lib.mkIf cfg.enable [ "grafana" ];
    })
  ];
}
