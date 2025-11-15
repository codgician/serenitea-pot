{
  config,
  pkgs,
  lib,
  outputs,
  ...
}:
let
  serviceName = "litellm";
  user = serviceName;
  inherit (lib) types;
  cfg = config.codgician.containers.${serviceName};
  uid = config.users.users.${user}.uid;
  allModels = (import ../../services/litellm/models.nix { inherit pkgs lib outputs; }).all;
  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "config.yaml" { model_list = allModels; };
in
{
  options.codgician.containers.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} container.";

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
      description = "Port for ${serviceName} to listen on.";
    };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = "Data directory for ${serviceName}.";
    };

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
      defaultProxyPass = with cfg; "http://${host}:${builtins.toString port}";
      defaultProxyPassText = ''with config.codgician.containers.${serviceName}; http://$\{host}:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = "ghcr.io/berriai/litellm:litellm_stable_release_branch-stable";
        volumes = [
          "${configFile}:/config.yaml:ro"
          "${cfg.stateDir}:/var/lib/litellm"
          "/run/postgresql:/run/postgresql"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--uidmap=0:${builtins.toString uid}:1"
          "--gidmap=0:${builtins.toString uid}:1"
        ];
        cmd = [
          "--port=${builtins.toString cfg.port}"
          "--host=${cfg.host}"
          "--config"
          "/config.yaml"
        ];
        environment = {
          "DO_NOT_TRACK" = "True";
          "GITHUB_COPILOT_TOKEN_DIR" = "/var/lib/litellm/github";
          "PGHOST" = cfg.adminUi.dbHost; # Hack for prisma to connect postgres with unix socket
        };
        environmentFiles = [ config.age.secrets.litellm-env.path ];
      };

      virtualisation.podman.enable = true;

      # Ensure litellm user is created
      codgician.users.${serviceName}.enable = true;

      # Persist default data directory
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/${serviceName}";
          inherit user;
          group = user;
        }
      ];
    })

    # Configure PostgreSQL for LiteLLM Admin UI
    (lib.mkIf (cfg.enable && cfg.adminUi.enable) {
      virtualisation.oci-containers.containers.${serviceName}.environment."DATABASE_URL" =
        "postgres://${user}@localhost/${cfg.adminUi.dbName}?host=/run/postgresql";

      codgician.services.postgresql.enable = true;
      services.postgresql = {
        ensureDatabases = [ cfg.adminUi.dbName ];
        ensureUsers = [
          {
            name = "litellm";
            ensureDBOwnership = true;
          }
        ];
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
