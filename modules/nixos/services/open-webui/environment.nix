{
  lib,
  cfg,
  ollamaEmbeddingModel,
  pgDbHost,
  pgDbName,
  doclingServeCfg,
  litellmCfg,
  ollamaCfg,
  redisCfg,
}:
let
  webuiUrl =
    if cfg.reverseProxy.enable then
      "${if cfg.reverseProxy.https then "https" else "http"}://${builtins.head cfg.reverseProxy.domains}"
    else
      "${cfg.host}:${builtins.toString cfg.port}";

  litellmBases = lib.optionals litellmCfg.enable [
    "http://${litellmCfg.host}:${builtins.toString litellmCfg.port}"
  ];
in
{
  # Enable CUDA
  USE_CUDA_DOCKER = "True";
  ENV = "prod";
  WEBUI_AUTH = "True";
  WEBUI_NAME = "Akasha";
  WEBUI_URL = webuiUrl;
  # OAuth
  ENABLE_SIGNUP = "False";
  ENABLE_LOGIN_FORM = "True";
  DEFAULT_USER_ROLE = "pending";
  ENABLE_OAUTH_SIGNUP = "False";
  OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
  OAUTH_CLIENT_ID = "akasha";
  # OAUTH_CLIENT_SECRET provided in env
  OPENID_REDIRECT_URI = "${webuiUrl}/oauth/oidc/callback";
  OPENID_PROVIDER_URL = "https://auth.codgician.me/.well-known/openid-configuration";
  OAUTH_PROVIDER_NAME = "Authelia";
  OAUTH_SCOPES = "openid email profile groups";
  ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
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
  ENABLE_OLLAMA_API = if ollamaCfg.enable then "True" else "False";
  OLLAMA_BASE_URL = lib.mkIf ollamaCfg.enable "http://${ollamaCfg.host}:${builtins.toString ollamaCfg.port}";
  # OpenAI (LiteLLM)
  ENABLE_OPENAI_API = if litellmCfg.enable then "True" else "False";
  OPENAI_API_BASE_URLS = lib.strings.concatStringsSep ";" litellmBases;
  # OPENAI_API_KEYS should be defined in UI
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
  # Image generation
  IMAGE_GENERATION_ENGINE = "gemini";
  ENABLE_IMAGE_GENERATION = "True";
  ENABLE_IMAGE_PROMPT_GENERATION = "True";
  IMAGE_GENERATION_MODEL = "imagen-4.0-generate-preview-06-06";
  IMAGE_SIZE = "1024x1024";
  IMAGES_GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";
  # Image edit
  IMAGE_EDIT_ENGINE = "gemini";
  IMAGE_EDIT_MODEL = "gemini-2.5-flash-image-preview";
  IMAGE_EDIT_SIZE = "1024x1024";
  # Redis
  ENABLE_WEBSOCKET_SUPPORT = "True";
  WEBSOCKET_MANAGER = "redis";
  WEBSOCKET_REDIS_URL = "unix://${redisCfg.servers.open-webui.unixSocket}";
  # Database
  DATABASE_URL = lib.mkIf (cfg.database == "postgresql") "postgresql:///${pgDbName}?host=${pgDbHost}";
  # Vector Database
  VECTOR_DB = lib.mkIf (cfg.database == "postgresql") "pgvector";
}
// (lib.optionalAttrs doclingServeCfg.enable {
  # Docling (PDF extraction engine)
  CONTENT_EXTRACTION_ENGINE = "docling";
  DOCLING_SERVER_URL = with doclingServeCfg; "http://${host}:${builtins.toString port}";
  DOCLING_OCR_ENGINE = "easyocr";
  DOCLING_OCR_LANG = "en,ch_sim";
})
