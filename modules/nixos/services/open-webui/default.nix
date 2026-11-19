{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "open-webui";
  cfg = config.codgician.services.open-webui;
  inherit (config.codgician) inventory;
  svc = inventory.services.open-webui;
  defaultStateDir = "/var/lib/${serviceName}";
  # Kept in its own directory: nginx serves the manifest's parent directory.
  pwaManifest = ./static/pwa-manifest.json;

  webuiUrl = "https://${svc.domain}";

  mcpoCfg = config.codgician.services.mcpo;
  pgDbName = "open-webui";
  pgDbHost = "/run/postgresql";

  # Branding
  appIcon =
    (pkgs.fetchurl {
      url = "https://media.githubusercontent.com/media/codgician/assets/465dc48eabca23c08f1e07ba8b0cf07fd7cf53d6/images/akasha/logo.png";
      sha256 = "sha256-aXa2So5dcthDY8B1UXvfu4Ym8RSTAmR+XWPRokVC9oA=";
    }).outPath;
  favicon =
    (pkgs.fetchurl {
      url = "https://media.githubusercontent.com/media/codgician/assets/465dc48eabca23c08f1e07ba8b0cf07fd7cf53d6/images/akasha/logo-round.png";
      sha256 = "sha256-qty11SyWzNgxkOsUvy1BUI5NgydUdXN1V6p7FvHhvTk=";
    }).outPath;
  splash = favicon;

  # Group id of "akasha-users" persisted in the open-webui database, referenced
  # by access grants baked into the persisted UI state below.
  akashaUsersGroupId = "b3840ad7-9a95-4fe6-950b-b68437209f70";
  akashaUsersReadGrant = {
    principal_type = "group";
    principal_id = akashaUsersGroupId;
    permission = "read";
  };

  # Tool servers are the MCP endpoints exposed by mcpo, each reachable at
  # http://127.0.0.1:<mcpo port>/<server name>. Presentation (display name and
  # description) and access scope are open-webui concerns, keyed by the mcpo
  # server name. Servers without an entry here fall back to their OpenAPI spec
  # for naming and are shared with akasha-users. "github" is admin-only (empty
  # grants), matching the state that was persisted in the database.
  toolServerMeta = {
    time = {
      name = "Time";
      description = "Get current time.";
    };
    fetch = {
      name = "Fetch";
      description = "Fetch file behind a URL.";
    };
    paper-search = {
      name = "Paper Search";
      description = "Search papers.";
    };
    google-maps = {
      name = "Google Maps";
      description = "Find locations on Google Maps";
    };
    amap-maps = {
      name = "高德地图";
      description = "Find location on Amaps (高德地图)";
    };
    grep_app = {
      name = "grep.app";
      description = "Rapid code search";
    };
    context7 = {
      name = "Context7";
      description = "Pulls up-to-date, version-specific documentation and code examples straight from the source.";
    };
    github = {
      name = "GitHub";
      description = "Access GitHub for code and operations";
      adminOnly = true;
    };
  };

  mkToolServer =
    name:
    let
      meta = toolServerMeta.${name} or { };
    in
    {
      url = "http://127.0.0.1:${builtins.toString mcpoCfg.port}/${name}";
      path = "openapi.json";
      type = "openapi";
      auth_type = "bearer";
      headers = null;
      key = "";
      config = {
        enable = true;
        function_name_filter_list = "";
        access_grants = lib.optional (!(meta.adminOnly or false)) akashaUsersReadGrant;
      };
      spec_type = "url";
      spec = "";
      info = {
        id = "";
        name = meta.name or name;
        description = meta.description or "";
      };
    };

  toolServerConnections = map mkToolServer mcpoCfg.servers;

  defaultModelMetadata.capabilities = {
    vision = true;
    citations = true;
    web_search = true;
    file_upload = true;
    file_context = true;
    builtin_tools = true;
    status_updates = true;
    code_interpreter = true;
    image_generation = true;
  };

  environment = {
    # The NixOS service has no GPU passthrough; keep local inference on CPU.
    USE_CUDA_DOCKER = "False";
    ENV = "prod";
    # Always honour environment variables over the database so configuration
    # stays consistent with this module. Values below mirror the state that was
    # previously persisted in the database while persistence was enabled.
    ENABLE_PERSISTENT_CONFIG = "False";
    WEBUI_AUTH = "True";
    WEBUI_NAME = "Akasha";
    WEBUI_URL = webuiUrl;
    # Security
    SAFE_MODE = "True";
    ENABLE_PLUGINS = "False";
    ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS = "False";
    # Branding
    EXTERNAL_PWA_MANIFEST_URL = "${webuiUrl}/static/pwa-manifest.json";
    # OAuth
    ENABLE_SIGNUP = "False";
    ENABLE_LOGIN_FORM = "False";
    DEFAULT_USER_ROLE = "pending";
    DEFAULT_GROUP_ID = "akasha-users";
    ENABLE_OAUTH_PERSISTENT_CONFIG = "False";
    ENABLE_OAUTH_SIGNUP = "True";
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
    OAUTH_CLIENT_ID = "akasha";
    # OAUTH_CLIENT_SECRET provided in env
    OPENID_REDIRECT_URI = "${webuiUrl}/oauth/oidc/callback";
    OPENID_PROVIDER_URL = "${inventory.autheliaUrl}/.well-known/openid-configuration";
    OAUTH_PROVIDER_NAME = "Authelia";
    OAUTH_SCOPES = "openid email profile groups";
    ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
    ENABLE_OAUTH_GROUP_MANAGEMENT = "True";
    OAUTH_ROLES_CLAIM = "groups";
    OAUTH_ALLOWED_ROLES = "akasha-users,akasha-admins";
    OAUTH_ADMIN_ROLES = "akasha-admins";
    OAUTH_REFRESH_TOKEN_INCLUDE_SCOPE = "True";
    # Logging
    # GLOBAL_LOG_LEVEL = "DEBUG";
    ENABLE_CHANNELS = "True";
    ENABLE_AUTOCOMPLETE_GENERATION = "True";
    AUTOCOMPLETE_GENERATION_INPUT_MAX_LENGTH = "-1";
    ENABLE_EVALUATION_ARENA_MODELS = "True";
    ENABLE_MESSAGE_RATING = "True";
    ENABLE_COMMUNITY_SHARING = "True";
    ENABLE_TAGS_GENERATION = "True";
    ENABLE_OLLAMA_API = "False";
    # OpenAI (LiteLLM)
    ENABLE_OPENAI_API = "True";
    # OPENAI_API_BASE_URLS, OPENAI_API_KEYS defined in environment
    # Enlarge chunk for image generation
    CHAT_STREAM_RESPONSE_CHUNK_MAX_BUFFER_SIZE = "20971520"; # 20MB
    # Security
    ENABLE_FORWARD_USER_INFO_HEADERS = "False";
    ENABLE_RAG_LOCAL_WEB_FETCH = "True";
    ENABLE_RAG_WEB_LOADER_SSL_VERIFICATION = "True";
    WEBUI_SESSION_COOKIE_SAME_SITE = "lax";
    RAG_FILE_MAX_SIZE = "100"; # MB
    # Search
    ENABLE_WEB_SEARCH = "True";
    WEB_SEARCH_ENGINE = "exa";
    WEB_SEARCH_RESULT_COUNT = "3";
    WEB_SEARCH_CONCURRENT_REQUESTS = "10";
    WEB_SEARCH_TRUST_ENV = "False";
    # Subagents
    ENABLE_SUBAGENTS = "True";
    SUBAGENTS_BACKGROUND_ENABLED = "True";
    # RAG
    ENABLE_RAG_HYBRID_SEARCH = "False";
    ENABLE_RAG_HYBRID_SEARCH_ENRICHED_TEXTS = "True";
    RAG_TEXT_SPLITTER = "token";
    CHUNK_SIZE = "800";
    # Use built-in loaders unless an extraction service overrides this.
    CONTENT_EXTRACTION_ENGINE = "";
    PDF_EXTRACT_IMAGES = "True";
    ENABLE_SEARCH_QUERY = "True";
    ENABLE_RAG_WEB_SEARCH = "True";
    RAG_WEB_SEARCH_ENGINE = "exa";
    # Qwen3 embeddings run inside Open WebUI on CPU.
    RAG_EMBEDDING_ENGINE = "";
    RAG_EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-0.6B";
    SENTENCE_TRANSFORMERS_HOME = "${cfg.stateDir}/cache/embedding/models";
    RAG_EMBEDDING_MODEL_AUTO_UPDATE = "False";
    # RAG_OPENAI_API_KEY provided in env
    RAG_TOP_K = "5";
    RAG_TOP_K_RERANKER = "5";
    RAG_RELEVANCE_THRESHOLD = "0.3";
    # Redis
    ENABLE_WEBSOCKET_SUPPORT = "True";
    WEBSOCKET_MANAGER = "redis";
    WEBSOCKET_REDIS_URL = "unix://${config.services.redis.servers.open-webui.unixSocket}";
    # Database
    DATABASE_URL = "postgresql:///${pgDbName}?host=${pgDbHost}";
    # Vector Database
    VECTOR_DB = "pgvector";
    # Image generation (OpenAI-compatible engine via LiteLLM)
    ENABLE_IMAGE_GENERATION = "True";
    IMAGE_GENERATION_ENGINE = "openai";
    IMAGE_GENERATION_MODEL = "gpt-image-2.5-flare";
    IMAGE_SIZE = "";
    ENABLE_IMAGE_EDIT = "True";
    IMAGE_EDIT_ENGINE = "openai";
    IMAGE_EDIT_MODEL = "gpt-image-2.5-sunburst";
    # IMAGES_OPENAI_API_BASE_URL / IMAGES_OPENAI_API_KEY and the edit variants
    # are provided through the environment file (secrets template).
    # Audio: browser-side speech-to-text (no server credentials required)
    AUDIO_STT_ENGINE = "web";
    # Connections, sharing and webhooks
    ENABLE_DIRECT_CONNECTIONS = "True";
    ENABLE_USER_WEBHOOKS = "True";
    JWT_EXPIRES_IN = "7d";
    TASK_MODEL_EXTERNAL = "deepseek-v4-pro";
    DEFAULT_MODEL_METADATA = builtins.toJSON defaultModelMetadata;
    # Misc
    ENABLE_REALTIME_CHAT_SAVE = "True";
    ENABLE_CHAT_RESPONSE_BASE64_IMAGE_URL_CONVERSION = "True";
  }
  // (lib.optionalAttrs mcpoCfg.enable {
    # Tool servers (MCP endpoints exposed by mcpo)
    TOOL_SERVER_CONNECTIONS = builtins.toJSON toolServerConnections;
  });
in
{
  options.codgician.services.open-webui = {
    enable = lib.codgician.mkPublishedEnableOption config serviceName;

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = defaultStateDir;
      description = "Directory to store open-webui data.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.open-webui.proxyPass = svc.localUpstream;

      services.open-webui = {
        enable = true;
        host = "127.0.0.1";
        inherit (svc) port;
        inherit (cfg) stateDir;
        package = pkgs.open-webui-akasha;
        inherit environment;
        environmentFile = config.codgician.secrets.templates."open-webui-env".path;
      };

      systemd.services.open-webui = {
        serviceConfig = {
          SupplementaryGroups = [
            # Ensure access to Redis
            config.services.redis.servers.open-webui.group
          ];

          # Disable dynamic user
          DynamicUser = lib.mkForce false;
          User = serviceName;
          Group = serviceName;
        };
      };

      # Set up Redis
      services.redis.servers.${serviceName} = {
        enable = true;
        unixSocketPerm = 660;
      };

      # Ensure state directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.stateDir != defaultStateDir) [
        "d ${cfg.stateDir} 0700 ${serviceName} ${serviceName} -"
      ];

      # Persist data when stateDir is default value
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.stateDir == defaultStateDir) [
        {
          type = "directory";
          path = cfg.stateDir;
          user = serviceName;
          group = serviceName;
        }
      ];

      # PostgreSQL
      codgician.services.postgresql.enable = true;
      services.postgresql = {
        extensions =
          ps: with ps; [
            pgvector
            # todo: extraxt this hack to a generic overlay
            (pgvectorscale.overrideAttrs (oldAttrs: {
              env = (oldAttrs.env or { }) // {
                RUSTFLAGS = (oldAttrs.env.RUSTFLAGS or "") + " -C target-feature=+avx2,+fma";
              };
            }))
          ];
        ensureDatabases = [ pgDbName ];
        ensureUsers = [
          {
            name = serviceName;
            ensureDBOwnership = true;
          }
        ];
      };
    })

    (lib.mkIf cfg.enable (
      lib.codgician.mkServiceUserGroupLinux serviceName {
        uid = 2026;
        gid = 2026;
      }
    ))

    # Locations of the vhost, next to the backend and on the edge alike; the
    # icons are only served next to the backend.
    (lib.mkIf (cfg.enable || config.codgician.services.nginx.fronts ? ${serviceName}) {
      codgician.services.nginx.reverseProxies.open-webui.locations =
        let
          inherit (lib.codgician) mkNginxLocationForStaticFile;
          convertImage = lib.codgician.convertImage pkgs;
          resizeImage =
            size: outName: image:
            convertImage image {
              args = "-background transparent -resize ${size}";
              inherit outName;
            };

          faviconIco = convertImage favicon {
            args = "-background transparent -define icon:auto-resize=16,24,32,48,64,72,96,128,256";
            outName = "favicon.ico";
          };
          favicon96 = resizeImage "96x96" "favicon-96x96.png" favicon;
          favicon512 = resizeImage "512x512" "favicon" appIcon;
        in
        {
          "= /static/pwa-manifest.json" = mkNginxLocationForStaticFile pwaManifest;
        }
        // (lib.optionalAttrs cfg.enable {
          "= /favicon.png" = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon.png" = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon-dark.png" = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon-96x96.png" = mkNginxLocationForStaticFile favicon96;
          "= /favicon.ico" = mkNginxLocationForStaticFile faviconIco;
          "= /static/favicon.ico" = mkNginxLocationForStaticFile faviconIco;
          "= /static/logo.png" = mkNginxLocationForStaticFile appIcon;
          "= /static/apple-touch-icon.png" = mkNginxLocationForStaticFile (
            resizeImage "180x180" "apple-touch-icon.png" appIcon
          );
          "= /static/web-app-manifest-192x192.png" = mkNginxLocationForStaticFile (
            resizeImage "192x192" "web-app-manifest-192x192.png" appIcon
          );
          "= /static/web-app-manifest-512x512.png" = mkNginxLocationForStaticFile (
            resizeImage "512x512" "web-app-manifest-512x512.png" appIcon
          );
          "= /static/splash.png" = mkNginxLocationForStaticFile splash;
          "= /static/splash-dark.png" = mkNginxLocationForStaticFile splash;
        })
        // {
          "/_app/immutable/".extraConfig = ''
            add_header Cache-Control "public, max-age=31536000, immutable";
          '';
          "/api/v1/files".extraConfig = ''
            client_max_body_size 128M;
            proxy_connect_timeout 1800;
            proxy_send_timeout 1800;
            proxy_read_timeout 1800;
            send_timeout 1800;
          '';
          "/".extraConfig = ''
            client_max_body_size 128M;
            proxy_buffering off;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
            proxy_read_timeout 300;
            send_timeout 300;
            # Prevent stale frontend after upgrades - browser must always fetch fresh HTML
            add_header Cache-Control "no-store, no-cache, must-revalidate" always;
          '';
        };
    })
  ];
}
