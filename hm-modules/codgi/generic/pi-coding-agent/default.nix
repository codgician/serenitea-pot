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

  # Filter text generation models by allowed providers (mirrors opencode's
  # dendro provider: all routed through the LiteLLM proxy).
  allowedProviders = [
    "chatgpt"
    "github"
    "anthropic"
    "nvidia"
    "vllm"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # pi thinking levels, in canonical order (see pi.dev/docs/latest/models).
  piThinkingLevels = [
    "off"
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
  ];

  # Each pi thinking level resolves to the first registry effort key the model
  # actually defines (preference order, first match wins). The map VALUE is the
  # exact effort string sent to the provider, so name mismatches are handled
  # precisely instead of relying on pi's default mapping:
  #   registry `none`  -> pi `off`     (Claude has no `none`, so it stays on)
  #   registry `max`   -> pi `xhigh`   (true ceiling, preferred over `xhigh`)
  #   registry `xhigh` -> pi `xhigh`   (only when the model has no `max`)
  # A Claude model that supports `max` natively therefore gets `xhigh -> "max"`
  # rather than a dropped or mismatched effort. Models exposing both `xhigh` and
  # `max` (Opus 4.7+) surface `max` at pi's ceiling; the intermediate `xhigh`
  # tier is shadowed because pi has no slot above `xhigh`.
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
  };

  # Resolve a pi level to the exact provider effort string, or null when the
  # model defines none of the candidate efforts (unsupported -> hidden in pi).
  resolvePiLevel =
    variantKeys: level:
    let
      candidates = builtins.filter (k: builtins.elem k variantKeys) piLevelToEffortKeys.${level};
    in
    if candidates == [ ] then null else builtins.head candidates;

  # Full `thinkingLevelMap`: every pi level mapped to its provider effort string
  # or null. Explicit string values (e.g. `xhigh -> "max"`) mirror the official
  # pi docs example and make the exact request payload auditable.
  mkThinkingLevelMap =
    m:
    let
      variantKeys = builtins.attrNames m.variants;
    in
    builtins.listToAttrs (
      map (level: lib.nameValuePair level (resolvePiLevel variantKeys level)) piThinkingLevels
    );

  # Transform a registry model into a pi model entry. `id` matches the LiteLLM
  # model name (m.model), and `input` mirrors opencode's modalities.
  mkPiModel =
    m:
    let
      hasReasoning = m.variants != { };
    in
    {
      id = m.model;
      input = [
        "text"
        "image"
      ];
      reasoning = hasReasoning;
    }
    // lib.optionalAttrs hasReasoning {
      thinkingLevelMap = mkThinkingLevelMap m;
    };

  piModels = map mkPiModel filteredModels;

  # Single OpenAI-compatible provider pointing at the dendro LiteLLM proxy,
  # authenticated with the per-user API key secret (read at request time).
  modelsJson = {
    providers.dendro = {
      baseUrl = "https://dendro.codgician.me/v1";
      api = "openai-responses";
      apiKey = "!cat ${osConfig.codgician.secrets.templates."litellm-user-api-key".path}";
      models = piModels;
    };
  };
in
{
  options.codgician.codgi.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.pi-coding-agent;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent";
      description = ''
        The pi-coding-agent package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".pi/agent/models.json".source = jsonFormat.generate "pi-models.json" modelsJson;
  };
}
