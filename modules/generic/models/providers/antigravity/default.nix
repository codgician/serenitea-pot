{ lib, modelLib, ... }:
let
  # SKU profiles are read from this account's fetchAvailableModels roster.
  # API-equivalent prices from https://ai.google.dev/gemini-api/docs/pricing.
  # Google doubles Argon/Carbon on 2026-12-01 and 3.8 Flash on 2027-01-01;
  # LiteLLM has no date-based pricing, so update these on those dates.
  definitions = {
    "gemini-4-argon" = {
      routes = {
        low = "gemini-4-argon-low";
        medium = "gemini-4-argon-medium";
        high = "gemini-4-argon-high";
      };
      maxOutputTokens = 65536;
      cost = {
        input = 2;
        output = 10;
        cacheRead = 0.1;
        cacheWrite = 0;
      };
    };
    "gemini-4-carbon" = {
      routes = {
        low = "gemini-4-carbon-low";
        medium = "gemini-4-carbon-medium";
        high = "gemini-4-carbon-high";
      };
      maxOutputTokens = 262144;
      cost = {
        input = 2;
        output = 10;
        cacheRead = 0.1;
        cacheWrite = 0;
      };
    };
    "gemini-3.8-flash" = {
      routes = {
        low = "gemini-3.8-flash-low";
        medium = "gemini-3.8-flash-medium";
        high = "gemini-3.8-flash-high";
      };
      maxOutputTokens = 65536;
      cost = {
        input = 0.75;
        output = 3.75;
        cacheRead = 0.075;
        cacheWrite = 0;
      };
    };
    "gemini-3.1-flash-lite" = {
      routes = lib.genAttrs [ "minimal" "low" "medium" "high" ] (_: "gemini-3.1-flash-lite");
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
          antigravity.routes = definitions.${name}.routes;
        };
      };
    models = lib.mapAttrs (
      _: definition:
      removeAttrs definition [ "routes" ]
      // {
        contextWindow = 1048576;
        maxInputTokens = 1048576;
        reasoningEfforts = builtins.attrNames definition.routes;
        variants = lib.mapAttrs (reasoningEffort: _: { inherit reasoningEffort; }) definition.routes;
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
