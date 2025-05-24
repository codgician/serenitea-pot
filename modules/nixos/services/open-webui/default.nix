{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "open-webui";
  cfg = config.codgician.services.open-webui;
  types = lib.types;
  listToStr = lib.strings.concatStringsSep ";";

  litellmCfg = config.codgician.services.litellm;
  litellmBases = lib.optionals litellmCfg.enable [
    "http://${litellmCfg.host}:${builtins.toString litellmCfg.port}"
  ];
  litellmKeys = lib.optionals litellmCfg.enable [ "dummy" ];

  ollamaCfg = config.codgician.services.ollama;

  pgDbHost = "/run/postgresql";
  pgDbName = serviceName;

  ollamaEmbeddingModel = "bge-m3";
in
{
  options.codgician.services.open-webui = {
    enable = lib.mkEnableOption "Open-webui.";

    package = lib.mkPackageOption pkgs "open-webui" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for open-webui to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3010;
      description = ''
        Port for open-webui to listen on.
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

    openFirewall = lib.mkEnableOption "Open firewall for open-webui.";

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

        splashDark = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/splash-dark.png";
          description = "Custom splash-dark.png for open-webui.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.open-webui = {
        enable = true;
        inherit (cfg)
          host
          port
          openFirewall
          package
          ;
        environmentFile = config.age.secrets.open-webui-env.path;
        environment = {
          # Enable CUDA
          USE_CUDA_DOCKER = "True";
          ENV = "prod";
          WEBUI_AUTH = "True";
          WEBUI_NAME = "Akasha";
          WEBUI_URL =
            if cfg.reverseProxy.enable then
              builtins.head cfg.reverseProxy.domains
            else
              "${cfg.host}:${builtins.toString cfg.port}";
          # Logging
          # GLOBAL_LOG_LEVEL = "DEBUG";
          # Features
          ENABLE_SIGNUP = "False";
          ENABLE_LOGIN_FORM = "True";
          DEFAULT_USER_ROLE = "pending";
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
          ENABLE_OPENAI_API = if litellmCfg.enable then "True" else "False";
          OPENAI_API_BASE_URLS = listToStr litellmBases;
          OPENAI_API_KEYS = listToStr litellmKeys;
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
          RAG_EMBEDDING_ENGINE = lib.mkIf ollamaCfg.enable "ollama";
          RAG_EMBEDDING_MODEL = lib.mkIf ollamaCfg.enable ollamaEmbeddingModel;
          RAG_OLLAMA_BASE_URL = lib.mkIf ollamaCfg.enable "http://${ollamaCfg.host}:${builtins.toString ollamaCfg.port}";
          # RAG_RERANKING_MODEL = "BAAI/bge-reranker-v2-m3";
          # Image generation
          IMAGE_GENERATION_ENGINE = "gemini";
          ENABLE_IMAGE_GENERATION = "True";
          ENABLE_IMAGE_PROMPT_GENERATION = "True";
          IMAGE_GENERATION_MODEL = "imagen-3.0-generate-002";
          IMAGE_SIZE = "1024x1024";
          IMAGES_GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
          # Redis
          ENABLE_WEBSOCKET_SUPPORT = "True";
          WEBSOCKET_MANAGER = "redis";
          WEBSOCKET_REDIS_URL = "unix://${config.services.redis.servers.open-webui.unixSocket}";
          # Database
          DATABASE_URL = lib.mkIf (cfg.database == "postgresql") "postgresql:///${pgDbName}?host=${pgDbHost}";
          # Vector Database
          VECTOR_DB = lib.mkIf (cfg.database == "postgresql") "pgvector";
        };
      };

      # Create user
      users.users.${serviceName} = {
        group = serviceName;
        isSystemUser = true;
      };
      users.groups.${serviceName} = { };

      # Add embedding model to ollama
      codgician.services.ollama.loadModels = [ ollamaEmbeddingModel ];

      # Set up Redis
      services.redis.servers.${serviceName} = {
        enable = true;
        unixSocketPerm = 660;
      };

      systemd.services.open-webui.serviceConfig = {

        SupplementaryGroups = [
          # Ensure access to Redis
          config.services.redis.servers.open-webui.group
          # For ROCm
          "render"
        ];

        # Allow access to GPU
        DeviceAllow = [
          # CUDA
          # https://docs.nvidia.com/dgx/pdf/dgx-os-5-user-guide.pdf
          "char-nvidiactl"
          "char-nvidia-caps"
          "char-nvidia-frontend"
          "char-nvidia-uvm"
          # ROCm
          "char-drm"
          "char-fb"
          "char-kfd"
          # WSL (Windows Subsystem for Linux)
          "/dev/dxg"
        ];

        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = serviceName;
        Group = serviceName;
      };

      # Persist data when dataDir is default value
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/open-webui";
          user = serviceName;
          group = serviceName;
        }
      ];
    })

    # PostgreSQL
    (lib.mkIf (cfg.enable && cfg.database == "postgresql") {
      # PostgreSQL
      codgician.services.postgresql.enable = true;
      services.postgresql = {
        extensions = ps: with ps; [ pgvector ];
        ensureDatabases = [ pgDbName ];
        ensureUsers = [
          {
            name = serviceName;
            ensureDBOwnership = true;
          }
        ];
      };

      # PostgreSQL: enable pgvector
      systemd.services.postgresql.serviceConfig.ExecStartPost =
        let
          sqlFile = pkgs.writeText "open-webui-pgvector-init.sql" ''
            CREATE EXTENSION IF NOT EXISTS vector;
          '';
        in
        ''
          ${lib.getExe' config.services.postgresql.package "psql"} -d "${pgDbName}" -f "${sqlFile}"  
        '';
    })

    (lib.mkIf cfg.enable (
      with lib.codgician; mkAgenixConfigs { } [ (getAgeSecretPathFromName "open-webui-env") ]
    ))

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
      overrideVhostConfig.locations =
        let
          inherit (cfg.reverseProxy)
            appIcon
            favicon
            splash
            splashDark
            ;
          convertFavicon = lib.codgician.convertImage pkgs favicon;
        in
        {
          "/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
            extraConfig = ''
              client_max_body_size 128M;
            '';
          };
        }
        // (lib.optionalAttrs (favicon != null) {
          "=/favicon.png".alias = favicon;
          "=/static/favicon.png".alias = favicon;
          "=/static/favicon-96x96.png".alias = convertFavicon {
            args = "-background transparent -resize 96x96";
            outName = "favicon-96x96.png";
          };
          "=/static/favicon.ico".alias = convertFavicon {
            args = "-background transparent -define icon:auto-resize=16,24,32,48,64,72,96,128,256";
            outName = "favicon.ico";
          };
        })
        // (lib.optionalAttrs (appIcon != null) {
          "=/static/apple-touch-icon.png".alias = appIcon;
        })
        // (lib.optionalAttrs (splash != null) {
          "=/static/splash.png".alias = splash;
        })
        // (lib.optionalAttrs (splashDark != null) {
          "=/static/splash-dark.png".alias = splashDark;
        });
    })
  ];
}
