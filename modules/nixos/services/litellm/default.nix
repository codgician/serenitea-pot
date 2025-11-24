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

  # Environment variables
  environment = {
    "DO_NOT_TRACK" = "True";
    "GITHUB_COPILOT_TOKEN_DIR" =
      if cfg.backend == "nixpkgs" then "${cfg.stateDir}/github" else "/config/github";
  }
  // (lib.optionalAttrs (cfg.adminUi.enable) {
    "PGHOST" = cfg.adminUi.dbHost; # Hack for prisma to connect postgres with unix socket
    "DATABASE_URL" = "postgres://${user}@localhost/${cfg.adminUi.dbName}?host=${cfg.adminUi.dbHost}";
  });

in
{
  options.codgician.services.litellm = {
    enable = lib.mkEnableOption "LiteLLM Proxy.";

    backend = lib.mkOption {
      type = lib.types.enum [
        "nixpkgs"
        "container"
      ];
      default = "nixpkgs";
      description = ''
        Backend to use for deploying LiteLLM.
      '';
    };

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

    # Note: this is not working in nix variant
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
    # Common configuration
    (lib.mkIf cfg.enable {
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

    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs") {
      services.litellm = {
        enable = true;
        inherit (cfg) host port stateDir;
        environmentFile = config.age.secrets.litellm-env.path;
        inherit environment;
        settings.model_list = allModels;
      };

      systemd.services.litellm.serviceConfig = {
        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = user;
        Group = group;
      };
    })

    # Container backend
    (lib.mkIf (cfg.enable && cfg.backend == "container") {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = "ghcr.io/berriai/litellm:litellm_stable_release_branch-stable";
        volumes = [
          "${(pkgs.formats.yaml { }).generate "config.yaml" { model_list = allModels; }}:/config.yaml:ro"
          "${cfg.stateDir}:/config"
          "/run/postgresql:/run/postgresql"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--userns=auto"
        ];
        cmd = with cfg; [
          "--port=${builtins.toString port}"
          "--host=${host}"
          "--config"
          "/config.yaml"
        ];
        inherit environment;
        environmentFiles = [ config.age.secrets.litellm-env.path ];
      };
    })

    # Configure PostgreSQL for LiteLLM Admin UI
    (lib.mkIf (cfg.enable && cfg.adminUi.enable) {
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
