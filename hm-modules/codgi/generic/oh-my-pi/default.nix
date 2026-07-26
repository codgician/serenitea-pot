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
    off = [ "none" ];
    minimal = [ "minimal" ];
    low = [ "low" ];
    medium = [ "medium" ];
    high = [ "high" ];
    xhigh = [
      "max"
      "xhigh"
    ];
    max = [
      "max"
      "xhigh"
    ];
  };

  # First candidate effort the model defines, or null when none.
  resolveEffort =
    effortKeys: candidates:
    let
      matches = builtins.filter (k: builtins.elem k effortKeys) candidates;
    in
    if matches == [ ] then null else builtins.head matches;

  # reasoningEffortMap: omp level -> upstream effort string, dropping levels the
  # model does not define.
  mkReasoningEffortMap =
    m:
    let
      effortKeys = m.reasoningEfforts;
    in
    lib.filterAttrs (_level: effort: effort != null) (
      builtins.mapAttrs (_level: resolveEffort effortKeys) ompLevelToEffortKeys
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
      contextWindow = m.contextWindow or null;
      maxTokens = m.maxOutputTokens or null;
      cost = m.cost or null;
      hasReasoning = m.reasoningEfforts != [ ] || builtins.elem "reasoning" (m.supports or [ ]);
      compat =
        lib.optionalAttrs (reasoningEffortMap != { }) { inherit reasoningEffortMap; }
        // lib.optionalAttrs (m.provider == "github") { supportsImageDetailOriginal = false; };
    in
    {
      id = m.model;
      api = modeToApi.${m.mode};
      input =
        m.input or [
          "text"
          "image"
        ];
      reasoning = hasReasoning;
    }
    // lib.optionalAttrs (compat != { }) { inherit compat; }
    // lib.optionalAttrs (contextWindow != null) { inherit contextWindow; }
    // lib.optionalAttrs (maxTokens != null) { inherit maxTokens; }
    // lib.optionalAttrs (cost != null) { inherit cost; };

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

  profiles = import ./profiles { inherit pkgs; };

  profileConfigFiles = builtins.mapAttrs (
    name: settings: yamlFormat.generate "omp-${name}-config.yml" settings
  ) profiles;

  modelsFile = yamlFormat.generate "omp-models.yml" modelsYaml;

  mkProfileFiles =
    name: agentDir:
    {
      "${agentDir}/config.yml" = {
        source = profileConfigFiles.${name};
        force = true;
      };
      "${agentDir}/AGENTS.md" = {
        text = ''
          # Environment

          This system is managed by Nix on `${pkgs.stdenv.hostPlatform.system}`.
          Prefer an existing project development environment. For a new persistent project environment, use a flake dev shell with direnv only when the user requests it.
        '';
        force = true;
      };
      "${agentDir}/RULES.md" = {
        text = ''
          # Git commits

          Never add `Co-Authored-By`, `Generated-By`, or other AI or Oh My Pi attribution to commit messages.
          Use the user's configured Git author and committer identity unchanged.

          # Packages

          On this Nix-managed system, use `nix run` or `nix shell` for one-off tools; never install packages imperatively.
        '';
        force = true;
      };
    }
    // lib.optionalAttrs (name != "github-copilot") {
      "${agentDir}/models.yml" = {
        source = modelsFile;
        force = true;
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

    defaultProfile = lib.mkOption {
      type = types.enum (builtins.attrNames profiles);
      default = "dendro";
      description = ''
        The oh-my-pi profile selected when no explicit --profile is given.
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
    // mkProfileFiles cfg.defaultProfile ".omp/agent"
    // lib.concatMapAttrs (name: _profile: mkProfileFiles name ".omp/profiles/${name}/agent") profiles;
  };
}
