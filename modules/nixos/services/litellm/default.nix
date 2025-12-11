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
  uid = config.users.users.${user}.uid;
  cfg = config.codgician.services.litellm;
  types = lib.types;
  allModels = (import ./models.nix { inherit pkgs lib outputs; }).all;

  # LiteLLM settings
  settings = {
    general_settings = {
      # enable_jwt_auth = true;
      store_model_in_db = true;
      store_prompts_in_spend_logs = true;
    };
    litellm_settings.drop_params = true;
    model_list = allModels;
  };

  # Environment variables
  environment = {
    "DO_NOT_TRACK" = "True";
    "GITHUB_COPILOT_TOKEN_DIR" =
      if cfg.backend == "nixpkgs" then "${cfg.stateDir}/github" else "/config/github";
  }
  // (lib.optionalAttrs (cfg.adminUi.enable) {
    PGHOST = cfg.adminUi.dbHost; # Hack for prisma to connect postgres with unix socket
    DATABASE_URL = "postgres://${user}@localhost/${cfg.adminUi.dbName}?host=${cfg.adminUi.dbHost}";
  })
  // (lib.optionalAttrs (cfg.adminUi.authelia.enable) {
    PROXY_BASE_URL = "https://${builtins.head cfg.reverseProxy.domains}";
    GENERIC_CLIENT_ID = "dendro";
    # GENERIC_CLIENT_SECRET in environment file
    GENERIC_AUTHORIZATION_ENDPOINT = "https://auth.codgician.me/api/oidc/authorization";
    GENERIC_TOKEN_ENDPOINT = "https://auth.codgician.me/api/oidc/token";
    GENERIC_USERINFO_ENDPOINT = "https://auth.codgician.me/api/oidc/userinfo";
    GENERIC_INCLUDE_CLIENT_ID = "true";
    # GENERIC_CLIENT_USE_PKCE = "true"; problematic with authelia
    GENERIC_SCOPE = "openid email profile groups";
    GENERIC_USER_ROLE_ATTRIBUTE = "groups";
    # JWT_PUBLIC_KEY_URL = "https://auth.codgician.me/jwks.json";
    # JWT_AUDIENCE = "dendro";
  });
in
{
  options.codgician.services.litellm = {
    enable = lib.mkEnableOption serviceName;

    backend = lib.mkOption {
      type = lib.types.enum [
        "nixpkgs"
        "container"
      ];
      default = "nixpkgs";
      description = ''
        Backend to use for deploying ${serviceName}.
      '';
    };

    imageTag = lib.mkOption {
      type = lib.types.enum [
        "main-latest"
        "main-dev"
        "main-stable"
      ];
      default = "main-stable";
      description = ''
        Container image tag for ${serviceName}.
      '';
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for ${serviceName} to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 5483;
      description = ''
        Port for ${serviceName} to listen on.
      '';
    };

    package = lib.mkPackageOption pkgs "litellm" { };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = ''
        Directory for ${serviceName} to store state data.
      '';
    };

    # Note: this is not working in nix variant
    # See: https://github.com/NixOS/nixpkgs/issues/432925
    adminUi = {
      enable = lib.mkEnableOption "${serviceName} Admin UI";

      authelia.enable = lib.mkEnableOption "Authelia";

      dbName = lib.mkOption {
        type = types.str;
        default = "litellm";
        description = "Database name for ${serviceName} Admin UI.";
      };

      dbHost = lib.mkOption {
        type = types.str;
        default = "/run/postgresql";
        description = "Database host for ${serviceName} Admin UI.";
      };
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://$\{host}:$\{builtins.toString port}'';
      extraOptions = {
        # Custom favicon
        favicon = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/favicon.png";
          description = "Custom favicon.png for ${serviceName}.";
        };
      };
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
        inherit environment settings;
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
        image = "ghcr.io/berriai/litellm:${cfg.imageTag}";
        volumes = [
          "${(pkgs.formats.yaml { }).generate "config.yaml" settings}:/config.yaml:ro"
          "${cfg.stateDir}:/config:U"
          "/run/postgresql:/run/postgresql"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--uidmap=0:${builtins.toString uid}:1"
          "--gidmap=0:${builtins.toString uid}:1"
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
      extraVhostConfig.locations =
        let
          inherit (cfg.reverseProxy) favicon;
          inherit (lib.codgician) mkNginxLocationForStaticFile;
          convertImage = lib.codgician.convertImage pkgs;
          faviconIco = convertImage favicon {
            args = "-background transparent -define icon:auto-resize=16,24,32,48,64,72,96,128,256";
            outName = "favicon.ico";
          };
        in
        (lib.optionalAttrs (favicon != null) {
          "= /favicon.png".passthru = mkNginxLocationForStaticFile favicon;
          "= /swagger/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
          "= /swagger/favicon.png".passthru = mkNginxLocationForStaticFile favicon;
          "= /ui/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
        });
    })
  ];
}
