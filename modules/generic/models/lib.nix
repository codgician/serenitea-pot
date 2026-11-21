{ lib }:
let
  inherit (lib) mkOption types;

  # What every provider's model spec may say.
  commonOptions = {
    aliases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Alternative names for this model.";
    };
    mode = mkOption {
      type = types.str;
      default = "chat";
      description = "LiteLLM mode: chat, responses, image_generation, embedding, …";
    };
    variants = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = "Request parameters by reasoning effort, where the provider wants more than the effort itself.";
    };
    reasoningEfforts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Reasoning efforts the provider accepts.";
    };
    path = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Name of the model at the provider; null for the registry name.";
    };
  };

  # What a spec refreshed from a provider's model list (`models.json`) adds.
  generatedOptions = commonOptions // {
    contextWindow = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Tokens of prompt and output together.";
    };
    maxInputTokens = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Largest prompt in tokens.";
    };
    maxOutputTokens = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Largest output in tokens.";
    };
    cost = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Prices per million tokens: `input`, `output`, `cacheRead`, `cacheWrite`, and `tiers` above a prompt size.";
    };
    supportedEndpoints = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "API paths the model is served at.";
    };
    supports = mkOption {
      type = types.listOf (
        types.enum [
          "toolCalls"
          "parallelToolCalls"
          "structuredOutputs"
          "vision"
          "reasoning"
        ]
      );
      default = [ ];
      description = "Capabilities of the model.";
    };
  };

  generatedCostInfo =
    cost:
    if cost == null then
      { }
    else
      let
        perToken = price: price / 1000000.0;
        tiers = cost.tiers or [ ];
        tier = if tiers == [ ] then null else builtins.head tiers;
        threshold = if tier == null then null else toString (tier.inputTokensAbove / 1000);
      in
      {
        input_cost_per_token = perToken cost.input;
        output_cost_per_token = perToken cost.output;
        cache_read_input_token_cost = perToken cost.cacheRead;
        cache_creation_input_token_cost = perToken cost.cacheWrite;
      }
      // lib.optionalAttrs (tier != null) {
        "input_cost_per_token_above_${threshold}k_tokens" = perToken tier.input;
        "output_cost_per_token_above_${threshold}k_tokens" = perToken tier.output;
        "cache_read_input_token_cost_above_${threshold}k_tokens" = perToken tier.cacheRead;
        "cache_creation_input_token_cost_above_${threshold}k_tokens" = perToken tier.cacheWrite;
      };

  generatedModelInfo =
    spec:
    generatedCostInfo spec.cost
    // {
      inherit (spec) mode;
    }
    // lib.optionalAttrs (spec.maxInputTokens != null) {
      max_input_tokens = spec.maxInputTokens;
    }
    // lib.optionalAttrs (spec.maxOutputTokens != null) {
      max_output_tokens = spec.maxOutputTokens;
      max_tokens = spec.maxOutputTokens;
    }
    // lib.optionalAttrs (spec.supportedEndpoints != [ ]) {
      supported_endpoints = spec.supportedEndpoints;
    }
    // lib.optionalAttrs (builtins.elem "toolCalls" spec.supports) {
      supports_function_calling = true;
      supports_tool_choice = true;
    }
    // lib.optionalAttrs (builtins.elem "parallelToolCalls" spec.supports) {
      supports_parallel_function_calling = true;
    }
    // lib.optionalAttrs (builtins.elem "structuredOutputs" spec.supports) {
      supports_response_schema = true;
    }
    // lib.optionalAttrs (builtins.elem "vision" spec.supports) {
      supports_vision = true;
    }
    // lib.optionalAttrs (builtins.elem "reasoning" spec.supports) {
      supports_reasoning = true;
    }
    // lib.optionalAttrs (builtins.elem "none" spec.reasoningEfforts) {
      supports_none_reasoning_effort = true;
    }
    // lib.optionalAttrs (builtins.elem "xhigh" spec.reasoningEfforts) {
      supports_xhigh_reasoning_effort = true;
    };
in
rec {
  inherit commonOptions;

  basicModelType = types.submodule { options = commonOptions; };
  generatedModelType = types.submodule { options = generatedOptions; };

  mkProviderType =
    modelType:
    types.submodule {
      options = {
        transformer = mkOption {
          type = types.raw;
          description = "Function that transforms a model spec into a registry entry";
        };
        models = mkOption {
          type = types.attrsOf modelType;
          default = { };
          description = "Model definitions for this provider";
        };
      };
    };

  mkModel =
    {
      modelPrefix,
      apiKeyEnv ? null,
      tags,
      extraParams ? { },
      extraModelInfo ? { },
    }:
    name: spec: {
      inherit (spec) aliases mode variants;
      reasoningEfforts = lib.unique (spec.reasoningEfforts ++ builtins.attrNames spec.variants);
      litellmModelInfo = {
        inherit (spec) mode;
      }
      // extraModelInfo;
      litellmParams = {
        model = "${modelPrefix}/${if spec.path != null then spec.path else name}";
      }
      // lib.optionalAttrs (apiKeyEnv != null) { api_key = "os.environ/${apiKeyEnv}"; }
      // extraParams;
      inherit tags;
    };

  mkGeneratedModel =
    {
      modelPrefix,
      apiKeyEnv ? null,
      extraParams ? { },
      tags,
    }:
    name: spec:
    (mkModel {
      inherit
        modelPrefix
        apiKeyEnv
        tags
        extraParams
        ;
      extraModelInfo = generatedModelInfo spec;
    } name spec)
    // {
      inherit (spec)
        contextWindow
        cost
        maxInputTokens
        maxOutputTokens
        supports
        ;
      input = [ "text" ] ++ lib.optional (builtins.elem "vision" spec.supports) "image";
    };
}
