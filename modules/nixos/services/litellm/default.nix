{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  serviceName = "litellm";
  user = serviceName;
  group = serviceName;
  cfg = config.codgician.services.litellm;
  types = lib.types;
  allModels = (import ./models.nix { inherit pkgs lib outputs; }).all;
in
{
  options.codgician.services.litellm = {
    enable = lib.mkEnableOption "LiteLLM Proxy.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for LiteLLM to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 5483;
      description = ''
        Port for LiteLLM to listen on.
      '';
    };

    package = lib.mkPackageOption pkgs "litellm" { };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = ''
        Directory for LiteLLM to store state data.
      '';
    };

    # Note: this is not working
    # See: https://github.com/NixOS/nixpkgs/issues/432925
    adminUi = {
      enable = lib.mkEnableOption "LiteLLM Admin UI";

      dbName = lib.mkOption {
        type = types.str;
        default = "litellm";
        description = "Database name for LiteLLM Admin UI.";
      };

      dbHost = lib.mkOption {
        type = types.str;
        default = "/run/postgresql";
        description = "Database host for LiteLLM Admin UI.";
      };
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://$\{host}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.litellm = {
        enable = true;
        inherit (cfg) host port stateDir;
        environmentFile = config.age.secrets.litellm-env.path;
        environment = {
          "DO_NOT_TRACK" = "True";
          "GITHUB_COPILOT_TOKEN_DIR" = "${cfg.stateDir}/github";
        };
        settings.model_list = allModels;
      };

      systemd.services.litellm.serviceConfig = {
        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = user;
        Group = group;
      };

      # Ensure litellm user is created
      codgician.users.${serviceName}.enable = true;

      # Persist default data directory
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/${serviceName}";
          inherit user group;
        }
      ];
    })

    # Configure PostgreSQL for LiteLLM Admin UI
    (lib.mkIf (cfg.enable && cfg.adminUi.enable) {
      codgician.services.postgresql.enable = true;
      services = {
        litellm.environment."DATABASE_URL" = "postgres:///${cfg.adminUi.dbName}?host=${cfg.adminUi.dbHost}";
        postgresql = {
          ensureDatabases = [ cfg.adminUi.dbName ];
          ensureUsers = [
            {
              name = "litellm";
              ensureDBOwnership = true;
            }
          ];
        };
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
