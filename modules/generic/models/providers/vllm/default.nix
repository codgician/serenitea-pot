{ lib, modelLib, ... }:
let
  inherit (lib) mkOption types;
in
{
  description = "Self-hosted vLLM (OpenAI-compatible) models";
  modelType = types.submodule {
    options = modelLib.commonOptions // {
      apiBase = mkOption {
        type = types.str;
        description = "Base URL of the vLLM-compatible OpenAI endpoint.";
      };
      contextWindow = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Tokens of prompt and output together that the endpoint serves.";
      };
    };
  };
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
        extraParams.api_base = spec.apiBase;
      } name spec)
      // lib.optionalAttrs (spec.contextWindow != null) { inherit (spec) contextWindow; };
    models."qwen3.8-27b" = {
      apiBase = "http://${lib.codgician.inventory.hosts.paimon.lan}:8000/v1";
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
