{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "litellm";
  user = serviceName;
  group = serviceName;
  uid = config.users.users.${user}.uid;
  cfg = config.codgician.services.litellm;
  types = lib.types;
  defaultStateDir = "/var/lib/${serviceName}";
  claudeOAuthHook = ./hooks;

  # Transform registry models to LiteLLM model_list format
  mkLiteLLMModel = m: {
    model_name = m.model;
    model_info = m.litellmModelInfo // {
      access_groups = m.tags;
    };
    litellm_params = m.litellmParams;
  };

  # Model list and alias map from registry
  allModels = map mkLiteLLMModel config.codgician.models.all;
  aliasMap = lib.foldl' (
    acc: m: acc // (lib.genAttrs m.aliases (_: m.model))
  ) { } config.codgician.models.all;

  # Cap upstream wait. Reverse proxy gets a margin so LiteLLM trips first.
  requestTimeout = 600;
  reverseProxyTimeout = requestTimeout + 30;

  # LiteLLM config
  settings = {
    general_settings = {
      # enable_jwt_auth = true;
      store_model_in_db = true;
      store_prompts_in_spend_logs = true;
      maximum_spend_logs_retention_period = "30d";
      maximum_spend_logs_retention_interval = "1d";
      maximum_spend_logs_cleanup_cron = "0 16 * * *";
      user_api_key_cache_ttl = "300";
    };
    litellm_settings = {
      num_retries = 3;
      cache = true;
      enable_redis_auth_cache = true;
      enable_caching_on_provider_specific_optional_params = true;
      cache_params = {
        type = "redis";
        namespace = "litellm.caching.caching";
        ttl = "60";
      };
      callbacks = [ "claude_oauth_hook.proxy_handler_instance" ];
      drop_params = true;
      modify_params = true;
      model_alias_map = aliasMap;
      request_timeout = requestTimeout;
      stream = true;
    };
    model_list = allModels;
  };

  # Redis socket path (different for container vs nixpkgs)
  redisSocketPath =
    if cfg.backend == "nixpkgs" then
      config.services.redis.servers.${serviceName}.unixSocket
    else
      "/run/redis-${serviceName}/redis.sock";

  # Environment variables
  environment = {
    "LITELLM_MODEL_COST_MAP_URL" =
      "https://raw.githubusercontent.com/codgician/litellm/refs/heads/my/model_prices_and_context_window.json";
    "PYTHONPATH" = if cfg.backend == "nixpkgs" then "${claudeOAuthHook}" else "/";
    # Require pending PR: https://github.com/BerriAI/litellm/pull/34889
    "GITHUB_COPILOT_CLIENT_ID" = "Ov23li8tweQw6odWQebz";
    "GITHUB_COPILOT_USER_AGENT" = "opencode/${pkgs.opencode.version}";
    "GITHUB_COPILOT_INTEGRATION_ID" = "";
    "GITHUB_COPILOT_EDITOR_VERSION" = "";
    "GITHUB_COPILOT_EDITOR_PLUGIN_VERSION" = "";
    "GITHUB_COPILOT_API_VERSION" = "2026-06-01";
    "GITHUB_COPILOT_OPENAI_INTENT" = "conversation-edits";
    "AUTO_REDIRECT_UI_LOGIN_TO_SSO" = "True";
    "DO_NOT_TRACK" = "True";
    "GITHUB_COPILOT_TOKEN_DIR" =
      if cfg.backend == "nixpkgs" then "${cfg.stateDir}/github" else "/config/github";
    "CHATGPT_TOKEN_DIR" =
      if cfg.backend == "nixpkgs" then "${cfg.stateDir}/chatgpt" else "/config/chatgpt";
    "XAI_OAUTH_TOKEN_DIR" = if cfg.backend == "nixpkgs" then "${cfg.stateDir}/xai" else "/config/xai";
    "REDIS_URL" = "unix://${redisSocketPath}";
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

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/codgician/litellm:my";
      description = ''
        Container image for ${serviceName}.
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

      # Set up Redis (use litellm user/group for socket access)
      services.redis.servers.${serviceName} = {
        enable = true;
        inherit user group;
        unixSocketPerm = 660;
      };

      # Make Redis runtime directory traversable for container with user namespace
      systemd.services."redis-${serviceName}".serviceConfig.RuntimeDirectoryMode = lib.mkForce "0755";

      # Ensure state directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.stateDir != defaultStateDir) [
        "d ${cfg.stateDir} 0700 ${user} ${group} -"
      ];

      # Persist default data directory
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.stateDir == defaultStateDir) [
        {
          type = "directory";
          path = cfg.stateDir;
          inherit user group;
        }
      ];
    })

    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs") {
      services.litellm = {
        enable = true;
        inherit (cfg) host port stateDir;
        environmentFile = config.codgician.secrets.templates."litellm-env".path;
        inherit environment settings;
      };

      systemd.services.litellm.serviceConfig = {
        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = user;
        Group = group;
        # Ensure access to Redis socket
        SupplementaryGroups = [ config.services.redis.servers.${serviceName}.group ];
      };
    })

    # Container backend
    (lib.mkIf (cfg.enable && cfg.backend == "container") {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = cfg.image;
        volumes = [
          "${(pkgs.formats.yaml { }).generate "config.yaml" settings}:/config.yaml:ro"
          "${claudeOAuthHook}/claude_oauth_hook.py:/claude_oauth_hook.py:ro"
          "${cfg.stateDir}:/config:U"
          "/run/postgresql:/run/postgresql"
          "/run/redis-${serviceName}:/run/redis-${serviceName}"
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
        environmentFiles = [ config.codgician.secrets.templates."litellm-env".path ];
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
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
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
          {
            # Align nginx timeouts with LiteLLM's request_timeout (plus margin).
            "/".passthru.extraConfig = ''
              proxy_connect_timeout ${builtins.toString reverseProxyTimeout}s;
              proxy_send_timeout ${builtins.toString reverseProxyTimeout}s;
              proxy_read_timeout ${builtins.toString reverseProxyTimeout}s;
            '';
          }
          // (lib.optionalAttrs (favicon != null) {
            "= /favicon.png".passthru = mkNginxLocationForStaticFile favicon;
            "= /swagger/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
            "= /swagger/favicon.png".passthru = mkNginxLocationForStaticFile favicon;
            "= /ui/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
          });
      };
    }
  ];
}
