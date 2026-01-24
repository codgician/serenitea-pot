{
  pkgs,
  lib,
  outputs,
  ...
}:

let
  # Import all available models from LiteLLM config
  allModels =
    builtins.filter
      (
        x:
        builtins.elem (x.model_info.mode or "") [
          "chat"
          "responses"
        ]
      )
      (import (lib.codgician.modulesDir + "/nixos/services/litellm/models.nix") {
        inherit lib pkgs outputs;
      }).all;

  # Convert model_info to OpenCode limit schema
  mkLimit =
    info:
    let
      limit =
        lib.optionalAttrs (info ? max_input_tokens) { context = info.max_input_tokens; }
        // lib.optionalAttrs (info ? max_output_tokens) { output = info.max_output_tokens; };
    in
    lib.optionalAttrs (limit != { }) { inherit limit; };

  # Helper to create model entries from filtered models
  mkModels =
    filter: extraAttrs:
    lib.pipe allModels [
      (builtins.filter filter)
      (map (x: {
        name = x.model_name;
        value = {
          name = x.model_name;
        }
        // extraAttrs
        // mkLimit (x.model_info or { });
      }))
      builtins.listToAttrs
    ];

  # Variants
  gpt5Variants = {
    high = {
      reasoningEffort = "high";
      textVerbosity = "high";
    };
    medium.reasoningEffort = "medium";
    low.reasoningEffort = "low";
    minimal.reasoningEffort = "minimal";
    none.reasoningEffort = "none";
  };

  gpt52Variants = gpt5Variants // {
    xhigh = {
      reasoningEffort = "xhigh";
      textVerbosity = "high";
    };
  };

  claudeVariants = {
    high.thinking = {
      type = "enabled";
      budgetTokens = 8000;
    };
    max.thinking = {
      type = "enabled";
      budgetTokens = 16000;
    };
  };

  geminiProVariants = {
    high.reasoningEffort = "high";
    low.reasoningEffort = "low";
  };
in
rec {
  gpt52 = mkModels (x: lib.hasPrefix "gpt-5.2" x.model_name) { variants = gpt52Variants; };
  gpt51 = mkModels (x: lib.hasPrefix "gpt-5.1" x.model_name) { variants = gpt5Variants; };

  claude45ThinkingModels = mkModels (
    x: x.model_name == "claude-opus-4.5" || x.model_name == "claude-sonnet-4.5"
  ) { variants = claudeVariants; };

  claude45NonThinkingModels = mkModels (x: x.model_name == "claude-haiku-4.5") { };

  geminiProModels = mkModels (x: lib.hasPrefix "gemini-3-pro" x.model_name) {
    variants = geminiProVariants;
  };

  geminiFlashModels = mkModels (x: lib.hasPrefix "gemini-3-flash" x.model_name) { };

  chinaModels = mkModels (
    x:
    lib.hasInfix "glm" x.model_name
    || lib.hasPrefix "minimax" x.model_name
    || lib.hasPrefix "deepseek" x.model_name
  ) { };

  all = lib.mergeAttrsList [
    gpt52
    gpt51
    claude45ThinkingModels
    claude45NonThinkingModels
    geminiProModels
    geminiFlashModels
    chinaModels
  ];
}
