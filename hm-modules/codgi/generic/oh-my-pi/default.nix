{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.oh-my-pi;
  inherit (lib) types;

  yamlFormat = pkgs.formats.yaml { };

  # Providers routed through the Dendro LiteLLM proxy. Family profiles filter
  # this shared registry without changing the transport path.
  allowedProviders = [
    "azure"
    "chatgpt"
    "deepseek"
    "github"
    "nvidia"
    "vllm"
    "xai"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # Registry mode -> omp API type. Each model talks to its native LiteLLM
  # surface, avoiding LiteLLM's chat<->responses bridging.
  modeToApi = {
    chat = "openai-completions";
    responses = "openai-responses";
  };

  # omp thinking level -> registry effort keys, in preference order (first key
  # the model defines wins). Map values are the exact effort strings sent
  # upstream via `compat.reasoningEffortMap`, so name mismatches resolve
  # precisely. omp's ceiling level is `max`, which outranks `xhigh`.
  ompLevelToEffortKeys = {
    minimal = [ "minimal" ];
    low = [ "low" ];
    medium = [ "medium" ];
    high = [ "high" ];
    xhigh = [
      "max"
      "xhigh"
    ];
  };

  # First candidate effort the model defines, or null when none.
  resolveEffort =
    variantKeys: candidates:
    let
      matches = builtins.filter (k: builtins.elem k variantKeys) candidates;
    in
    if matches == [ ] then null else builtins.head matches;

  # reasoningEffortMap: omp level -> upstream effort string, dropping levels the
  # model does not define.
  mkReasoningEffortMap =
    m:
    let
      variantKeys = builtins.attrNames m.variants;
    in
    lib.filterAttrs (_level: effort: effort != null) (
      builtins.mapAttrs (_level: resolveEffort variantKeys) ompLevelToEffortKeys
    );

  # Registry model -> omp model entry. `id` matches the LiteLLM model name.
  #
  # Every model is fronted by the single `dendro` LiteLLM proxy, so omp cannot
  # detect the true upstream host. GitHub Copilot's Responses endpoint rejects
  # snapcompact's `detail: "original"` image hint with a 400 ("image detail has
  # to be either 'low' or 'high'"), and omp's built-in clamp only fires when it
  # recognizes the Copilot host/provider directly. Force
  # `compat.supportsImageDetailOriginal = false` for Copilot-backed (`github`)
  # models so omp degrades the hint to `detail: "auto"` before it hits the wire.
  mkOmpModel =
    m:
    let
      reasoningEffortMap = mkReasoningEffortMap m;
      compat =
        lib.optionalAttrs (reasoningEffortMap != { }) { inherit reasoningEffortMap; }
        // lib.optionalAttrs (m.provider == "github") { supportsImageDetailOriginal = false; };
    in
    {
      id = m.model;
      api = modeToApi.${m.mode};
      input = [
        "text"
        "image"
      ];
      reasoning = m.variants != { };
    }
    // lib.optionalAttrs (compat != { }) { inherit compat; };

  ompModels = map mkOmpModel filteredModels;

  # OpenAI-compatible custom provider for the dendro LiteLLM proxy. Per-model
  # `api` picks the surface; `apiKey` reads the secret at request time via the
  # `!<command>` stdout-expansion form.
  modelsYaml = {
    providers.dendro = {
      baseUrl = "https://dendro.codgician.me/v1";
      api = "openai-completions";
      authHeader = true;
      apiKey = "!cat ${osConfig.codgician.secrets.templates."litellm-user-api-key".path}";
      models = ompModels;
    };
  };

  # The default profile is plain `omp` at ~/.omp/agent. Named profiles inherit
  # this configuration and store their OMP-native state separately.
  profiles = {
    default = {
      setupVersion = 1;

      modelRoles = {
        default = "dendro/gpt-5.6-sol";
        smol = "dendro/gpt-5.4-mini";
        task = "dendro/claude-sonnet-5";
        slow = "dendro/claude-opus-4-8:xhigh";
        plan = "dendro/claude-opus-4-8:xhigh";
        advisor = "dendro/claude-sonnet-5:medium";
        vision = "dendro/gemini-3.1-pro-preview:high";
        designer = "dendro/gemini-3.1-pro-preview:high";
        commit = "dendro/kimi-k2.6";
        tiny = "dendro/gpt-5.4-mini";
      };
      modelProviderOrder = [ "dendro" ];
      providers.webSearch = "exa";
      defaultThinkingLevel = "high";

      statusLine.preset = "full";
      tools = {
        approvalMode = "yolo";
        discoveryMode = "auto";
      };
      secrets.enabled = true;
      task = {
        batch = true;
        maxConcurrency = 8;
        isolation = {
          mode = "auto";
          merge = "patch";
        };
        showResolvedModelBadge = true;
      };
      async.enabled = true;
      skills = {
        enabled = true;
        enableSkillCommands = true;
        enableCodexUser = false;
        enableClaudeUser = false;
        enableClaudeProject = true;
        enablePiUser = false;
        enablePiProject = true;
        enableAgentsUser = false;
        enableAgentsProject = true;
        customDirectories = [ "${pkgs.nur.repos.codgician.agent-browser.src}/skills" ];
      };
      advisor = {
        enabled = false;
        subagents = false;
        syncBacklog = "off";
      };
      memory.backend = "off";
      autolearn = {
        enabled = false;
        autoContinue = false;
      };
      github.enabled = true;
      compaction = {
        enabled = true;
        strategy = "snapcompact";
        midTurnEnabled = true;
        remoteEnabled = true;
        autoContinue = true;
      };
    };

    # Family-isolated profiles for user-driven comparisons. Each one overrides
    # every role so background work cannot silently cross model families.
    gpt = {
      enabledModels = [
        "dendro/gpt-5.2"
        "dendro/gpt-5.2-codex"
        "dendro/gpt-5.3-codex"
        "dendro/gpt-5.4"
        "dendro/gpt-5.4-mini"
        "dendro/gpt-5.5"
        "dendro/gpt-5.6-luna"
        "dendro/gpt-5.6-terra"
        "dendro/gpt-5.6-sol"
      ];
      modelRoles = {
        default = "dendro/gpt-5.6-terra:high";
        smol = "dendro/gpt-5.4-mini";
        task = "dendro/gpt-5.6-luna:medium";
        slow = "dendro/gpt-5.6-sol:xhigh";
        plan = "dendro/gpt-5.6-sol:xhigh";
        advisor = "dendro/gpt-5.5:high";
        vision = "dendro/gpt-5.5:medium";
        designer = "dendro/gpt-5.5:medium";
        commit = "dendro/gpt-5.4-mini";
        tiny = "dendro/gpt-5.4-mini";
      };
    };

    claude = {
      enabledModels = [
        "dendro/claude-haiku-4-5"
        "dendro/claude-sonnet-4-6"
        "dendro/claude-sonnet-5"
        "dendro/claude-opus-4-6"
        "dendro/claude-opus-4-7"
        "dendro/claude-opus-4-8"
      ];
      modelRoles = {
        default = "dendro/claude-sonnet-5";
        smol = "dendro/claude-haiku-4-5";
        task = "dendro/claude-sonnet-5";
        slow = "dendro/claude-opus-4-8:xhigh";
        plan = "dendro/claude-opus-4-8:xhigh";
        advisor = "dendro/claude-opus-4-8:high";
        vision = "dendro/claude-sonnet-5:high";
        designer = "dendro/claude-sonnet-5:high";
        commit = "dendro/claude-haiku-4-5";
        tiny = "dendro/claude-haiku-4-5";
      };
    };

    gemini = {
      enabledModels = [
        "dendro/gemini-3.1-pro-preview"
        "dendro/gemini-3.5-flash"
      ];
      modelRoles = {
        default = "dendro/gemini-3.1-pro-preview:high";
        smol = "dendro/gemini-3.5-flash:low";
        task = "dendro/gemini-3.5-flash:high";
        slow = "dendro/gemini-3.1-pro-preview:high";
        plan = "dendro/gemini-3.1-pro-preview:high";
        advisor = "dendro/gemini-3.1-pro-preview:high";
        vision = "dendro/gemini-3.1-pro-preview:high";
        designer = "dendro/gemini-3.1-pro-preview:high";
        commit = "dendro/gemini-3.5-flash:low";
        tiny = "dendro/gemini-3.5-flash:low";
      };
    };

    grok = {
      enabledModels = [ "dendro/grok-4.5" ];
      modelRoles = {
        default = "dendro/grok-4.5:medium";
        smol = "dendro/grok-4.5:low";
        task = "dendro/grok-4.5:medium";
        slow = "dendro/grok-4.5:high";
        plan = "dendro/grok-4.5:high";
        advisor = "dendro/grok-4.5:high";
        vision = "dendro/grok-4.5:high";
        designer = "dendro/grok-4.5:high";
        commit = "dendro/grok-4.5:low";
        tiny = "dendro/grok-4.5:low";
      };
    };

    china = {
      enabledModels = [
        "dendro/deepseek-v4-flash"
        "dendro/deepseek-v4-pro"
        "dendro/kimi-k2.6"
      ];
      modelRoles = {
        default = "dendro/deepseek-v4-pro:high";
        smol = "dendro/deepseek-v4-flash:low";
        task = "dendro/deepseek-v4-flash:high";
        slow = "dendro/deepseek-v4-pro:high";
        plan = "dendro/deepseek-v4-pro:high";
        advisor = "dendro/kimi-k2.6";
        vision = "dendro/deepseek-v4-pro:high";
        designer = "dendro/deepseek-v4-pro:high";
        commit = "dendro/kimi-k2.6";
        tiny = "dendro/deepseek-v4-flash:low";
      };
    };

    private = {
      enabledModels = [ "dendro/qwen3.6-27b-int4" ];
      cycleOrder = [ "default" ];
      defaultThinkingLevel = "minimal";
      modelRoles = {
        default = "dendro/qwen3.6-27b-int4";
        smol = "dendro/qwen3.6-27b-int4";
        task = "dendro/qwen3.6-27b-int4";
        slow = "dendro/qwen3.6-27b-int4";
        plan = "dendro/qwen3.6-27b-int4";
        advisor = "dendro/qwen3.6-27b-int4";
        vision = "dendro/qwen3.6-27b-int4";
        designer = "dendro/qwen3.6-27b-int4";
        commit = "dendro/qwen3.6-27b-int4";
        tiny = "dendro/qwen3.6-27b-int4";
      };
      web_search.enabled = false;
      fetch.enabled = false;
      browser.enabled = false;
      github.enabled = false;
      images.blockImages = true;
      compaction = {
        strategy = "context-full";
        remoteEnabled = false;
      };
    };
  };

in
{
  options.codgician.codgi.oh-my-pi = {
    enable = lib.mkEnableOption "oh-my-pi (omp)";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.nur.repos.codgician.oh-my-pi-bin;
      defaultText = lib.literalExpression "pkgs.nur.repos.codgician.oh-my-pi-bin";
      description = ''
        The oh-my-pi package to install.
      '';
    };

  };

  config = lib.mkIf cfg.enable {

    home.packages = [ cfg.package ];
    home.file = {
      ".omp/.env" = {
        source = config.lib.file.mkOutOfStoreSymlink osConfig.codgician.secrets.templates."omp-env".path;
        force = true;
      };
    }
    // lib.mergeAttrsList (
      lib.mapAttrsToList (
        name: profile:
        let
          isDefault = name == "default";
          agentDir = if isDefault then ".omp/agent" else ".omp/profiles/${name}/agent";
          outputName = if isDefault then "omp" else "omp-${name}";
          settings = if isDefault then profile else lib.recursiveUpdate profiles.default profile;
        in
        {
          "${agentDir}/config.yml" = {
            source = yamlFormat.generate "${outputName}-config.yml" settings;
            force = true;
          };
          "${agentDir}/models.yml" = {
            source = yamlFormat.generate "omp-models.yml" modelsYaml;
            force = true;
          };
        }
      ) profiles
    );
  };
}
