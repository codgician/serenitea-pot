{
  lib,
  # tests/models imports this file without naming a provider.
  provider ? "unknown",
}:
let
  modelDefaults = {
    aliases = [ ];
    mode = "chat";
    variants = { };
    reasoningEfforts = [ ];
    path = null;
  };

  generatedDefaults = modelDefaults // {
    contextWindow = null;
    maxInputTokens = null;
    maxOutputTokens = null;
    cost = null;
    supportedEndpoints = [ ];
    supports = [ ];
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
  mkModel =
    {
      modelPrefix,
      apiKeyEnv ? null,
      tags,
      extraParams ? { },
      extraModelInfo ? { },
      extraKeys ? [ ],
    }:
    name: attrs:
    let
      spec = modelDefaults // attrs;
      unknownKeys = builtins.attrNames (
        removeAttrs attrs (builtins.attrNames modelDefaults ++ extraKeys)
      );
    in
    assert lib.assertMsg (
      unknownKeys == [ ]
    ) "codgician.models: unknown keys in ${provider} model '${name}': ${toString unknownKeys}";
    {
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
    name: attrs:
    let
      spec = generatedDefaults // attrs;
    in
    (mkModel {
      inherit
        modelPrefix
        apiKeyEnv
        tags
        extraParams
        ;
      extraModelInfo = generatedModelInfo spec;
      extraKeys = builtins.attrNames generatedDefaults;
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
