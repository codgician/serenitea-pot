{ lib, modelLib, ... }:
let
  modelType = lib.types.submodule {
    options = modelLib.commonOptions // {
      apiBase = lib.mkOption {
        type = lib.types.str;
        description = "Base URL of the vLLM-compatible OpenAI endpoint";
      };
      contextWindow = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum combined prompt and output token count served by the endpoint";
      };
    };
  };
in
{
  description = "Self-hosted vLLM (OpenAI-compatible) models";
  inherit modelType;
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
    models."qwen3.8-27b-fp8" = {
      apiBase = "http://192.168.0.22:8000/v1";
      contextWindow = 262144;
      path = "Qwen/Qwen3.8-27B-FP8";
      reasoningEfforts = [
        "low"
        "medium"
        "xhigh"
      ];
    };
  };
}
