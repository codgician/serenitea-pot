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

  # Providers routed through the dendro LiteLLM proxy (mirrors pi-coding-agent).
  allowedProviders = [
    "chatgpt"
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
  mkOmpModel =
    m:
    let
      hasReasoning = m.variants != { };
      reasoningEffortMap = mkReasoningEffortMap m;
    in
    {
      id = m.model;
      api = modeToApi.${m.mode};
      input = [
        "text"
        "image"
      ];
      reasoning = hasReasoning;
    }
    // lib.optionalAttrs (hasReasoning && reasoningEffortMap != { }) {
      compat = { inherit reasoningEffortMap; };
    };

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

    home.file.".omp/agent/models.yml".source = yamlFormat.generate "omp-models.yml" modelsYaml;
  };
}
