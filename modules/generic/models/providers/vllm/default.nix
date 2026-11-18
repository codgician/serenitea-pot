{ lib, modelLib, ... }:
{
  provider = {
    transformer =
      name: spec:
      (modelLib.mkModel {
        modelPrefix = "hosted_vllm";
        apiKeyEnv = "HOSTED_VLLM_API_KEY";
        tags = [
          "vllm"
          "local"
        ];
        extraKeys = [
          "apiBase"
          "contextWindow"
        ];
        extraParams.api_base = spec.apiBase;
      } name spec)
      // lib.optionalAttrs (spec ? contextWindow) { inherit (spec) contextWindow; };
    models."qwen3.8-27b" = {
      apiBase = "http://192.168.0.22:8000/v1";
      contextWindow = 262144;
      path = "Qwen3.8-27B";
      reasoningEfforts = [
        "low"
        "medium"
        "xhigh"
      ];
    };
  };
}
