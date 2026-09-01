{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.pi-coding-agent;
  inherit (lib) types;

  jsonFormat = pkgs.formats.json { };

  # Providers routed through the dendro LiteLLM proxy (mirrors opencode).
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

  # Registry mode -> pi API type. Each model talks to its native LiteLLM
  # surface, avoiding LiteLLM's chat<->responses bridging.
  modeToApi = {
    chat = "openai-completions";
    responses = "openai-responses";
  };

  # pi thinking level -> registry effort keys, in preference order (first key
  # the model defines wins). Map values are the exact effort strings sent
  # upstream, so name mismatches resolve precisely. `max` outranks `xhigh` at
  # pi's ceiling, so Claude models reach `max` natively.
  piLevelToEffortKeys = {
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

  # First candidate effort the model defines, or null when none (hidden in pi).
  resolveEffort =
    effortKeys: candidates:
    let
      matches = builtins.filter (k: builtins.elem k effortKeys) candidates;
    in
    if matches == [ ] then null else builtins.head matches;

  # thinkingLevelMap: every pi level -> effort string or null.
  mkThinkingLevelMap =
    m:
    let
      effortKeys = m.reasoningEfforts;
    in
    builtins.mapAttrs (_level: resolveEffort effortKeys) piLevelToEffortKeys;

  # Registry model -> pi model entry. `id` matches the LiteLLM model name.
  mkPiModel =
    m:
    let
      hasReasoning = m.reasoningEfforts != [ ] || builtins.elem "reasoning" (m.supports or [ ]);
      contextWindow = m.contextWindow or null;
      maxTokens = m.maxOutputTokens or null;
      cost = m.cost or null;
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
    // lib.optionalAttrs hasReasoning {
      thinkingLevelMap = mkThinkingLevelMap m;
    }
    // lib.optionalAttrs (contextWindow != null) { inherit contextWindow; }
    // lib.optionalAttrs (maxTokens != null) { inherit maxTokens; }
    // lib.optionalAttrs (cost != null) { inherit cost; };

  piModels = map mkPiModel filteredModels;

  # OpenAI-compatible provider for the dendro LiteLLM proxy. Per-model `api`
  # picks the surface; `apiKey` reads the secret at request time.
  modelsJson = {
    providers.dendro = {
      baseUrl = "https://dendro.codgician.me/v1";
      api = "openai-completions";
      apiKey = "!cat ${osConfig.codgician.secrets.files."litellm-user-api-key".path}";
      models = piModels;
    };
  };
in
{
  options.codgician.codgi.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.llm-agents.pi;
      defaultText = lib.literalExpression "pkgs.llm-agents.pi";
      description = ''
        The pi-coding-agent package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = {
      ".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" modelsJson;
    }
    // lib.optionalAttrs (config.codgician.codgi.herdr.enable or false) {
      ".pi/agent/skills/herdr".source = "${config.codgician.codgi.herdr.package.src}/skills/herdr";
    };
  };
}
