{ lib, modelLib, ... }:
let
  data = builtins.fromJSON (builtins.readFile ./models.json);
  metadata = {
    "minimaxai/minimax-m2.7" = {
      contextWindow = 204800;
      supports = [ "reasoning" ];
    };
    "minimaxai/minimax-m3" = {
      contextWindow = 1000000;
      supports = [
        "vision"
        "reasoning"
      ];
    };
    "nvidia/nemotron-3-embed-1b" = {
      mode = "embedding";
      supportedEndpoints = [ "/v1/embeddings" ];
    };
    "nvidia/nemotron-3-nano-30b-a3b" = {
      contextWindow = 1048576;
      supports = [
        "toolCalls"
        "structuredOutputs"
        "reasoning"
      ];
    };
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning" = {
      contextWindow = 262144;
      supports = [
        "vision"
        "reasoning"
      ];
    };
    "nvidia/nemotron-3-super-120b-a12b" = {
      contextWindow = 1048576;
      supports = [
        "toolCalls"
        "structuredOutputs"
        "reasoning"
      ];
    };
    "nvidia/nemotron-3-ultra-550b-a55b" = {
      contextWindow = 1048576;
      supports = [
        "toolCalls"
        "structuredOutputs"
        "reasoning"
      ];
    };
    "nvidia/nemotron-3.5-content-safety" = {
      mode = "moderation";
      contextWindow = 131072;
      supports = [ "vision" ];
      supportedEndpoints = [ ];
    };
    "nvidia/nemotron-4-340b-instruct".contextWindow = 4096;
    "nvidia/nemotron-4-340b-reward" = {
      mode = "rerank";
      supportedEndpoints = [ ];
    };
    "nvidia/nemotron-mini-4b-instruct".supports = [ "toolCalls" ];
    "nvidia/nemotron-nano-12b-v2-vl".supports = [
      "vision"
      "toolCalls"
    ];
    "nvidia/nemotron-parse" = {
      mode = "ocr";
      supports = [ "vision" ];
      supportedEndpoints = [ ];
    };
    "z-ai/glm-5.2" = {
      contextWindow = 1000000;
      supports = [
        "toolCalls"
        "structuredOutputs"
        "reasoning"
      ];
    };
  };
  modelName = id: builtins.elemAt (lib.splitString "/" id) 1;
  names = map modelName (builtins.attrNames data);
  models =
    assert builtins.length names == builtins.length (lib.unique names);
    lib.mapAttrs' (
      id: spec:
      lib.nameValuePair (modelName id) (
        {
          path = id;
          supportedEndpoints = [ "/v1/chat/completions" ];
        }
        // (metadata.${id} or { })
        // spec
      )
    ) data;
in
{
  description = "NVIDIA NIM models";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer = modelLib.mkGeneratedModel {
      modelPrefix = "nvidia_nim";
      apiKeyEnv = "NVIDIA_NIM_API_KEY";
      tags = [
        "nvidia"
        "remote"
      ];
    };
    inherit models;
  };
}
