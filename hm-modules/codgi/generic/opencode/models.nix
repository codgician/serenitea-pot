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

  # Define variants for GPT-5.x
  gpt5Variants = {
    high = {
      reasoningEffort = "high";
      textVerbosity = "low";
    };
    medium.reasoningEffort = "medium";
    low.reasoningEffort = "low";
    minimal.reasoningEffort = "minimal";
    none.reasoningEffort = "none";
  };

  gpt52Variants = gpt5Variants // {
    xhigh = {
      reasoningEffort = "xhigh";
      textVerbosity = "low";
    };
  };

  # Define variants for Claude models
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

  # Define variants for Gemini Pro models
  geminiProVariants = {
    high.reasoningEffort = "high";
    low.reasoningEffort = "low";
  };
in
rec {
  gpt52 = lib.pipe allModels [
    (builtins.filter (x: lib.hasPrefix "gpt-5.2" x.model_name))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
        variants = gpt52Variants;
      };
    }))
    builtins.listToAttrs
  ];

  gpt51 = lib.pipe allModels [
    (builtins.filter (x: lib.hasPrefix "gpt-5.1" x.model_name))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
        variants = gpt5Variants;
      };
    }))
    builtins.listToAttrs
  ];

  claude45ThinkingModels = lib.pipe allModels [
    (builtins.filter (x: x.model_name == "claude-opus-4.5" || x.model_name == "claude-sonnet-4.5"))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
        variants = claudeVariants;
      };
    }))
    builtins.listToAttrs
  ];

  claude45NonThinkingModels = lib.pipe allModels [
    (builtins.filter (x: x.model_name == "claude-haiku-4.5"))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
      };
    }))
    builtins.listToAttrs
  ];

  geminiProModels = lib.pipe allModels [
    (builtins.filter (x: lib.hasPrefix "gemini-3-pro" x.model_name))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
        variants = geminiProVariants;
      };
    }))
    builtins.listToAttrs
  ];

  geminiFlashModels = lib.pipe allModels [
    (builtins.filter (x: lib.hasPrefix "gemini-3-flash" x.model_name))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
      };
    }))
    builtins.listToAttrs
  ];

  chinaModels = lib.pipe allModels [
    (builtins.filter (
      x:
      lib.hasInfix "glm" x.model_name
      || lib.hasPrefix "minimax" x.model_name
      || lib.hasPrefix "deepseek" x.model_name
    ))
    (builtins.map (x: {
      name = x.model_name;
      value = {
        name = x.model_name;
      };
    }))
    builtins.listToAttrs
  ];

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
