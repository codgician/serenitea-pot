{ ref, pubkeys, ... }:
{
  publicKeys = pubkeys.someHosts [ pubkeys.hosts.paimon ];
  content = ''
    LLM_API_KEY=${ref "mirofish-llm-api-key"}
    LLM_BASE_URL=${ref "mirofish-llm-base-url"}
    LLM_MODEL_NAME=${ref "mirofish-llm-model-name"}
    ZEP_API_KEY=${ref "mirofish-zep-api-key"}
  '';
}
