{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon ];
  content = ''
    WEBUI_SECRET_KEY=${ref "open-webui-secret-key"}
    GOOGLE_PSE_ENGINE_ID=${ref "open-webui-google-pse-engine-id"}
    GOOGLE_PSE_API_KEY=${ref "open-webui-google-pse-api-key"}
    IMAGES_GEMINI_API_KEY=${ref "gemini-api-key"}
    OAUTH_CLIENT_SECRET=${ref "open-webui-oauth-client-secret"}
    OPENAI_API_BASE_URLS=${ref "open-webui-openai-api-base-urls"}
  '';
}
