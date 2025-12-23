{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "open-webui";
  cfg = config.codgician.services.open-webui;
  types = lib.types;

  webuiUrl =
    if cfg.reverseProxy.enable then
      "${if cfg.reverseProxy.https then "https" else "http"}://${builtins.head cfg.reverseProxy.domains}"
    else
      "${cfg.host}:${builtins.toString cfg.port}";

  ollamaCfg = config.codgician.services.ollama;
  ollamaEmbeddingModel = "hf.co/jinaai/jina-embeddings-v4-text-retrieval-GGUF:Q4_K_M";
  pgDbName = "open-webui";
  pgDbHost = "/run/postgresql";

  environment = {
    # Enable CUDA
    USE_CUDA_DOCKER = "True";
    ENV = "prod";
    WEBUI_AUTH = "True";
    WEBUI_NAME = "Akasha";
    WEBUI_URL = webuiUrl;
    WEBUI_BUILD_HASH = cfg.package.src.rev;
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
    OPENID_PROVIDER_URL = "https://auth.codgician.me/.well-known/openid-configuration";
    OAUTH_PROVIDER_NAME = "Authelia";
    OAUTH_SCOPES = "openid email profile groups";
    ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
    ENABLE_OAUTH_GROUP_MANAGEMENT = "True";
    OAUTH_ROLES_CLAIM = "groups";
    OAUTH_ALLOWED_ROLES = "akasha-users,akasha-admins";
    OAUTH_ADMIN_ROLES = "akasha-admins";
    # Logging
    # GLOBAL_LOG_LEVEL = "DEBUG";
    ENABLE_CHANNELS = "True";
    ENABLE_AUTOCOMPLETE_GENERATION = "True";
    AUTOCOMPLETE_GENERATION_INPUT_MAX_LENGTH = "-1";
    ENABLE_EVALUATION_ARENA_MODELS = "True";
    ENABLE_MESSAGE_RATING = "True";
    ENABLE_COMMUNITY_SHARING = "True";
    ENABLE_TAGS_GENERATION = "True";
    # Ollama
    ENABLE_OLLAMA_API = if config.services.ollama.enable then "True" else "False";
    OLLAMA_BASE_URL = lib.mkIf ollamaCfg.enable "http://${ollamaCfg.host}:${builtins.toString ollamaCfg.port}";
    # OpenAI (LiteLLM)
    ENABLE_OPENAI_API = "True";
    # OPENAI_API_BASE_URLS, OPENAI_API_KEYS defined in environment
    # TTS
    TTS_ENGINE = "transformers";
    WHISPER_MODEL = "large-v3-turbo";
    WHISPER_MODEL_AUTO_UPDATE = "True";
    AUDIO_TTS_ENGINE = "transformers";
    # Security
    ENABLE_FORWARD_USER_INFO_HEADERS = "False";
    ENABLE_RAG_LOCAL_WEB_FETCH = "True";
    ENABLE_RAG_WEB_LOADER_SSL_VERIFICATION = "True";
    WEBUI_SESSION_COOKIE_SAME_SITE = "lax";
    RAG_FILE_MAX_SIZE = "100"; # MB
    # Search
    ENABLE_WEB_SEARCH = "True";
    WEB_SEARCH_ENGINE = "google_pse";
    WEB_SEARCH_RESULT_COUNT = "5";
    WEB_SEARCH_CONCURRENT_REQUESTS = "10";
    # RAG
    ENABLE_RAG_HYBRID_SEARCH = "True";
    PDF_EXTRACT_IMAGES = "True";
    ENABLE_SEARCH_QUERY = "True";
    ENABLE_RAG_WEB_SEARCH = "True";
    RAG_WEB_SEARCH_ENGINE = "google_pse";
    # RAG_EMBEDDING_MODEL = "jinaai/jina-embeddings-v3";
    # RAG_RERANKING_MODEL = "jinaai/jina-reranker-v2-base-multilingual";
    RAG_RERANKING_MODEL = "jinaai/jina-reranker-m0";
    RAG_EMBEDDING_ENGINE = lib.mkIf ollamaCfg.enable "ollama";
    RAG_EMBEDDING_MODEL = lib.mkIf ollamaCfg.enable ollamaEmbeddingModel;
    RAG_OLLAMA_BASE_URL = lib.mkIf ollamaCfg.enable "http://${ollamaCfg.host}:${builtins.toString ollamaCfg.port}";
    RAG_TOP_K = "5";
    RAG_TOP_K_RERANKER = "5";
    RAG_RELEVANCE_THRESHOLD = "0.3";
    # Redis
    ENABLE_WEBSOCKET_SUPPORT = "True";
    WEBSOCKET_MANAGER = "redis";
    WEBSOCKET_REDIS_URL = "unix://${config.services.redis.servers.open-webui.unixSocket}";
    # Database
    DATABASE_URL = lib.mkIf (cfg.database == "postgresql") "postgresql:///${pgDbName}?host=${pgDbHost}";
    # Vector Database
    VECTOR_DB = lib.mkIf (cfg.database == "postgresql") "pgvector";
    # Misc
    ENABLE_REALTIME_CHAT_SAVE = "True";
    ENABLE_CHAT_RESPONSE_BASE64_IMAGE_URL_CONVERSION = "True";
  }
  // (lib.optionalAttrs config.codgician.services.docling-serve.enable {
    # Docling (PDF extraction engine)
    CONTENT_EXTRACTION_ENGINE = "docling";
    DOCLING_SERVER_URL =
      with config.codgician.services.docling-serve;
      "http://${host}:${builtins.toString port}";
    DOCLING_OCR_ENGINE = "rapidocr";
    DOCLING_OCR_LANG = "english,chinese";
  });
in
{
  options.codgician.services.open-webui = {
    enable = lib.mkEnableOption serviceName;

    backend = lib.mkOption {
      type = types.enum [ "nixpkgs" ];
      default = "nixpkgs";
      description = ''
        Backend to use for deploying open-webui.
      '';
    };

    package = lib.mkPackageOption pkgs "open-webui" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for ${serviceName} to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3010;
      description = ''
        Port for ${serviceName} to listen on.
      '';
    };

    database = lib.mkOption {
      type = types.enum [
        "sqlite"
        "postgresql"
      ];
      default = "sqlite";
      example = "postgresql";
      description = "Database backend for open-webui.";
    };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = "Directory to store open-webui data.";
    };

    openFirewall = lib.mkEnableOption "Open firewall for ${serviceName}";

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.open-webui; http://$\{host}:$\{toString port}'';
      extraOptions = {
        # Custom favicon
        favicon = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/favicon.png";
          description = "Custom favicon.png for open-webui.";
        };

        appIcon = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/app-icon.png";
          description = "Custom app icon for open-webui.";
        };

        # Custom splash
        splash = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/splash.png";
          description = "Custom splash.png for open-webui.";
        };
      };
    };
  };

  config = lib.mkMerge [
    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs") {
      services.open-webui = {
        enable = true;
        inherit (cfg)
          host
          port
          stateDir
          openFirewall
          package
          ;
        inherit environment;
        environmentFile = config.age.secrets.open-webui-env.path;
      };

      systemd.services.open-webui.serviceConfig = {
        SupplementaryGroups = [
          # Ensure access to Redis
          config.services.redis.servers.open-webui.group
        ];

        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = serviceName;
        Group = serviceName;
      };
    })

    # Common options
    (lib.mkIf cfg.enable {
      # Add embedding model to ollama
      codgician.services.ollama.loadModels = [ ollamaEmbeddingModel ];

      # Set up Redis
      services.redis.servers.${serviceName} = {
        enable = true;
        unixSocketPerm = 660;
      };

      # Persist data when dataDir is default value
      codgician.system.impermanence.extraItems =
        lib.mkIf (cfg.stateDir == options.codgician.services.open-webui.stateDir.default)
          [
            {
              type = "directory";
              path = "/var/lib/${serviceName}";
              user = serviceName;
              group = serviceName;
            }
          ];
    })

    # User
    (lib.mkIf cfg.enable (
      lib.codgician.mkServiceUserGroupLinux serviceName {
        uid = 2026;
        gid = 2026;
      }
    ))

    # PostgreSQL
    (lib.mkIf (cfg.enable && cfg.database == "postgresql") {
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

    # User
    (lib.mkIf cfg.enable (
      lib.codgician.mkServiceUserGroupLinux serviceName {
        uid = 2026;
        gid = 2026;
      }
    ))

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
      extraVhostConfig.locations =
        let
          inherit (cfg.reverseProxy)
            appIcon
            favicon
            splash
            ;

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
        (lib.optionalAttrs (favicon != null) {
          "= /favicon.png".passthru = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon.png".passthru = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon-dark.png".passthru = mkNginxLocationForStaticFile favicon512;
          "= /static/favicon-96x96.png".passthru = mkNginxLocationForStaticFile favicon96;
          "= /favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
          "= /static/favicon.ico".passthru = mkNginxLocationForStaticFile faviconIco;
        })
        // (lib.optionalAttrs (appIcon != null) {
          "= /static/logo.png".passthru = mkNginxLocationForStaticFile appIcon;
          "= /static/apple-touch-icon.png".passthru = mkNginxLocationForStaticFile (
            resizeImage "180x180" "apple-touch-icon.png" appIcon
          );
          "= /static/web-app-manifest-192x192.png".passthru = mkNginxLocationForStaticFile (
            resizeImage "192x192" "web-app-manifest-192x192.png" appIcon
          );
          "= /static/web-app-manifest-512x512.png".passthru = mkNginxLocationForStaticFile (
            resizeImage "512x512" "web-app-manifest-512x512.png" appIcon
          );
        })
        // (lib.optionalAttrs (splash != null) {
          "= /static/splash.png".passthru = mkNginxLocationForStaticFile splash;
          "= /static/splash-dark.png".passthru = mkNginxLocationForStaticFile splash;
        })
        // {
          "/".passthru.extraConfig = ''
            client_max_body_size 128M;
            proxy_buffering off;
            proxy_connect_timeout 300;
            proxy_send_timeout 300;
            proxy_read_timeout 300;
            send_timeout 300;
            add_header Cache-Control "no-cache";
          '';
          "~ ^/api/v1/files" = {
            inherit (cfg.reverseProxy) lanOnly;
            passthru = {
              inherit (cfg.reverseProxy) proxyPass;
              extraConfig = ''
                client_max_body_size 128M;
                proxy_connect_timeout 1800;
                proxy_send_timeout 1800;
                proxy_read_timeout 1800;
                send_timeout 1800;
              '';
            };
          };
        };
    })
  ];
}
