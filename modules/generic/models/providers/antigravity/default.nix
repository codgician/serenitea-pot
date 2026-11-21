{ lib, modelLib, ... }:
let
  # Efforts mirror this account's fetchAvailableModels groupedModels; the hook
  # picks the SKU (e.g. gemini-4-neon-xhigh) from the live roster.
  # API-equivalent prices from https://ai.google.dev/gemini-api/docs/pricing.
  # Google doubles Argon/Carbon on 2026-12-01 and 3.8 Flash on 2027-01-01;
  # LiteLLM has no date-based pricing, so update these on those dates.
  definitions = {
    "gemini-4-neon" = {
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
      ];
      maxOutputTokens = 262144;
      cost = {
        input = 3;
        output = 15;
        cacheRead = 0.15;
        cacheWrite = 0;
      };
    };
    "gemini-4-hydrogen" = {
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
      ];
      maxOutputTokens = 262144;
      cost = {
        input = 1.5;
        output = 7.5;
        cacheRead = 0.075;
        cacheWrite = 0;
      };
    };
    "gemini-4-argon" = {
      maxOutputTokens = 65536;
      cost = {
        input = 2;
        output = 10;
        cacheRead = 0.1;
        cacheWrite = 0;
      };
    };
    "gemini-4-carbon" = {
      maxOutputTokens = 262144;
      cost = {
        input = 2;
        output = 10;
        cacheRead = 0.1;
        cacheWrite = 0;
      };
    };
    "gemini-3.8-flash" = {
      maxOutputTokens = 65536;
      cost = {
        input = 0.75;
        output = 3.75;
        cacheRead = 0.075;
        cacheWrite = 0;
      };
    };
    # One SKU; LiteLLM maps its effort to a thinking level.
    "gemini-3.1-flash-lite" = {
      efforts = [
        "minimal"
        "low"
        "medium"
        "high"
      ];
      maxOutputTokens = 65535;
      cost = {
        input = 0.25;
        output = 1.5;
        cacheRead = 0.025;
        cacheWrite = 0;
      };
    };
  };
in
{
  description = "Gemini models through the Antigravity subscription";
  modelType = modelLib.generatedModelType;
  provider = {
    transformer =
      name: spec:
      let
        model = modelLib.mkGeneratedModel {
          modelPrefix = "antigravity";
          tags = [
            "antigravity"
            "google"
            "remote"
          ];
          extraParams.allowed_openai_params = [ "reasoning_effort" ];
        } name spec;
      in
      model
      // {
        litellmModelInfo = model.litellmModelInfo // {
          # Custom providers advertise LiteLLM's generic OpenAI-like params, which
          # omit reasoning_effort; base_model advertises the Gemini set instead.
          # Explicit prices above still take precedence for spend.
          base_model = "gemini/${name}";
          reasoning_effort_levels = spec.reasoningEfforts;
        };
      };
    models = lib.mapAttrs (
      _: definition:
      let
        efforts =
          definition.efforts or [
            "low"
            "medium"
            "high"
          ];
      in
      removeAttrs definition [ "efforts" ]
      // {
        contextWindow = 1048576;
        maxInputTokens = 1048576;
        reasoningEfforts = efforts;
        variants = lib.genAttrs efforts (reasoningEffort: {
          inherit reasoningEffort;
        });
        supports = [
          "vision"
          "reasoning"
          "toolCalls"
          "parallelToolCalls"
          "structuredOutputs"
        ];
      }
    ) definitions;
  };
}
