{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon ];
  content = ''
    WEBUI_SECRET_KEY=${ref "open-webui-secret-key"}
    GOOGLE_PSE_ENGINE_ID=${ref "google-pse-engine-id"}
    GOOGLE_PSE_API_KEY=${ref "google-pse-api-key"}
    OAUTH_CLIENT_SECRET=${ref "open-webui-oauth-client-secret"}
    OPENAI_API_BASE_URLS="https://dendro.codgician.me/v1;http://127.0.0.1:8000/v1"
    OPENAI_API_KEYS="${ref "litellm-akasha-api-key"};${ref "vllm-api-key"}"
    IMAGES_OPENAI_API_BASE_URL="https://dendro.codgician.me/v1"
    IMAGES_OPENAI_API_KEY="${ref "litellm-akasha-api-key"}"
    IMAGES_EDIT_OPENAI_API_BASE_URL="https://dendro.codgician.me/v1"
    IMAGES_EDIT_OPENAI_API_KEY="${ref "litellm-akasha-api-key"}"
  '';
}
