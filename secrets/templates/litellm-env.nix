{ ref }:
{
  content = ''
    LITELLM_MASTER_KEY=${ref "litellm-master-key"}
    GENERIC_CLIENT_SECRET=${ref "litellm-oidc-client-secret"}
    PROXY_ADMIN_ID=${ref "litellm-proxy-admin-id"}
    UI_USERNAME=${ref "litellm-proxy-admin-id"}
    UI_PASSWORD=${ref "litellm-ui-password"}
    AZURE_AKASHA_API_KEY=${ref "azure-akasha-api-key"}
    GEMINI_API_KEY=${ref "gemini-api-key"}
    DEEPSEEK_API_KEY=${ref "deepseek-api-key"}
    NVIDIA_NIM_API_KEY=${ref "nvidia-nim-api-key"}
    HOSTED_VLLM_API_KEY=${ref "vllm-api-key"}
    CLAUDE_CODE_OAUTH_TOKEN=${ref "claude-code-oauth-token"}
  '';
}
