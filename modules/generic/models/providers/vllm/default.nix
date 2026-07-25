{ lib, modelLib, ... }:
let
  modelType = lib.types.submodule {
    options = modelLib.commonOptions // {
      apiBase = lib.mkOption {
        type = lib.types.str;
        description = "Base URL of the vLLM-compatible OpenAI endpoint";
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
      modelLib.mkModel {
        modelPrefix = "hosted_vllm";
        apiKeyEnv = "HOSTED_VLLM_API_KEY";
        tags = [
          "vllm"
          "local"
        ];
        extraParams.api_base = spec.apiBase;
      } name spec;
    models."qwen3.6-27b-int4" = {
      apiBase = "http://192.168.0.22:8000/v1";
      path = "Intel/Qwen3.6-27B-int4-AutoRound";
    };
  };
}
