{ config, lib, ... }:
let
  cfg = config.codgician.services.open-webui;
  types = lib.types;
  listToStr = lib.strings.concatStringsSep ";";

  litellmCfg = config.codgician.services.litellm;
  litellmBases = lib.optionals litellmCfg.enable [
    "http://${litellmCfg.host}:${builtins.toString litellmCfg.port}"
  ];
  litellmKeys = lib.optionals litellmCfg.enable [ "dummy" ];

  ollamaCfg = config.codgician.services.ollama;
in
{
  options.codgician.services.open-webui = {
    enable = lib.mkEnableOption "Open-webui.";

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

    openFirewall = lib.mkEnableOption "Open firewall for open-webui.";

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for open-webui.";

      favicon = lib.mkOption {
        type = types.nullOr types.path;
        example = "/path/to/favicon.png";
        default = null;
        description = ''
          Path to the customized favicon.png file.
        '';
      };

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
        default = "http://${cfg.host}:${builtins.toString cfg.port}";
        defaultText = ''http://$\{config.codgician.services.open-webui.host\}:$\{toString config.codgician.services.open-webui.port\}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.open-webui = {
        enable = true;
        inherit (cfg) host port openFirewall;
        environmentFile = config.age.secrets.openWebuiEnv.path;
        environment = {
          ENV = "prod";
          WEBUI_AUTH = "True";
          WEBUI_NAME = "Akasha";
          WEBUI_URL =
            if cfg.reverseProxy.enable then
              builtins.head cfg.reverseProxy.domains
            else
              "${cfg.host}:${builtins.toString cfg.port}";
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
          # RAG
          ENABLE_RAG_HYBRID_SEARCH = "True";
          PDF_EXTRACT_IMAGES = "True";
          ENABLE_SEARCH_QUERY = "True";
          ENABLE_RAG_WEB_SEARCH = "True";
          RAG_WEB_SEARCH_ENGINE = "google_pse";
          RAG_EMBEDDING_ENGINE = lib.mkIf ollamaCfg.enable "ollama";
          RAG_EMBEDDING_MODEL = lib.mkIf ollamaCfg.enable "qllama/bge-m3:latest";
          RAG_OLLAMA_BASE_URL = lib.mkIf ollamaCfg.enable "http://${ollamaCfg.host}:${builtins.toString ollamaCfg.port}";
          RAG_RERANKING_MODEL = "BAAI/bge-reranker-v2-m3";
          # Redis
          ENABLE_WEBSOCKET_SUPPORT = "True";
          WEBSOCKET_MANAGER = "redis";
          WEBSOCKET_REDIS_URL = "unix://${config.services.redis.servers.open-webui.unixSocket}";
        };
      };

      # Add embedding model to ollama
      codgician.services.ollama.loadModels = [
        "qllama/bge-m3:latest"
      ];

      # Set up Redis
      services.redis.servers.open-webui = {
        enable = true;
        unixSocketPerm = 660;
      };

      # Ensure access to Redis
      systemd.services.open-webui.serviceConfig.SupplementaryGroups = [
        config.services.redis.servers.open-webui.group
      ];
    })

    (lib.mkIf cfg.enable (
      with lib.codgician; mkAgenixConfigs { } [ (secretsDir + "/openWebuiEnv.age") ]
    ))

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.open-webui = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
          locations."=/static/favicon.png" =
            with cfg.reverseProxy;
            lib.mkIf (favicon != null) { alias = favicon; };
        };
      };
    })
  ];
}
