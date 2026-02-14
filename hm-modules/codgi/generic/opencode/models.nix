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
      limit = lib.filterAttrs (_: v: v != null) {
        context = info.max_input_tokens or null;
        output = info.max_output_tokens or null;
      };
    in
    lib.optionalAttrs (limit != { }) { inherit limit; };

  # Variant generator: takes model name, returns variants attr set
  getVariants =
    name:
    let
      m = builtins.match "^gpt-([0-9]+(\\.[0-9]+)?)(-codex.*)?$" name;
      gptVersion = if m == null then null else builtins.elemAt m 0;
    in
    # GPT-5+ family models (no suffix or -codex suffix only)
    if gptVersion != null && lib.versionAtLeast gptVersion "5" then
      {
        high = {
          reasoningEffort = "high";
          textVerbosity = "high";
        };
        medium.reasoningEffort = "medium";
        low.reasoningEffort = "low";
        minimal.reasoningEffort = "minimal";
        none.reasoningEffort = "none";
      }
      // lib.optionalAttrs (lib.versionAtLeast gptVersion "5.2") {
        xhigh = {
          reasoningEffort = "xhigh";
          textVerbosity = "high";
        };
      }
    # Claude thinking models (opus/sonnet)
    else if lib.hasPrefix "claude-opus" name || lib.hasPrefix "claude-sonnet" name then
      {
        high.thinking = {
          type = "enabled";
          budget_tokens = 16000;
        };
        max.thinking = {
          type = "enabled";
          budget_tokens = 31999;
        };
      }
    # Gemini Pro models
    else if lib.hasPrefix "gemini-3-pro" name then
      {
        high.reasoningEffort = "high";
        low.reasoningEffort = "low";
      }
    # No variants for other models
    else
      { };

  # Helper to create model entries from filtered models
  mkModels =
    pred:
    builtins.listToAttrs (
      map (
        x:
        let
          name = x.model_name;
          variants = getVariants name;
        in
        lib.nameValuePair name (
          {
            inherit name;
          }
          // lib.optionalAttrs (variants != { }) { inherit variants; }
          // mkLimit (x.model_info or { })
        )
      ) (builtins.filter pred allModels)
    );

  # Model family predicates
  families = {
    gpt = x: lib.hasPrefix "gpt-" x.model_name;
    claude = x: lib.hasPrefix "claude-" x.model_name;
    gemini = x: lib.hasPrefix "gemini-3-" x.model_name;
    china =
      x:
      lib.any (p: p x.model_name) [
        (lib.hasInfix "glm")
        (lib.hasPrefix "minimax")
        (lib.hasPrefix "deepseek")
      ];
  };

  grouped = lib.mapAttrs (_: mkModels) families;
in
grouped // { all = lib.mergeAttrsList (builtins.attrValues grouped); }
