{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.pi-coding-agent;
  agents = import ../agents.nix args;

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

  # Registry model -> pi model entry. `id` matches the LiteLLM model name.
  mkPiModel =
    m:
    let
      hasReasoning = m.reasoningEfforts != [ ] || builtins.elem "reasoning" (m.supports or [ ]);
      cost = m.cost or null;
    in
    {
      id = m.model;
      api = agents.modeToApi.${m.mode};
      input =
        m.input or [
          "text"
          "image"
        ];
      reasoning = hasReasoning;
    }
    // lib.optionalAttrs hasReasoning {
      # Every pi level -> effort string, or null (hidden in pi) when the model defines none.
      thinkingLevelMap = lib.mapAttrs (
        _: lib.findFirst (effort: builtins.elem effort m.reasoningEfforts) null
      ) piLevelToEffortKeys;
    }
    // agents.modelLimits m
    // lib.optionalAttrs (cost != null) { inherit cost; };

  # OpenAI-compatible provider for the dendro LiteLLM proxy. Per-model `api`
  # picks the surface; `apiKey` reads the secret at request time.
  modelsJson = {
    providers.dendro = {
      baseUrl = "${agents.dendroUrl}/v1";
      api = agents.modeToApi.chat;
      apiKey = agents.apiKeyCommand;
      models = map mkPiModel (
        agents.modelsFrom [
          "chatgpt"
          "github"
          "nvidia"
          "vllm"
          "xai"
        ]
      );
    };
  };
in
{
  options.codgician.codgi.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent";
    package = lib.mkPackageOption pkgs [ "llm-agents" "pi" ] { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = {
      ".pi/agent/models.json".source = (pkgs.formats.json { }).generate "pi-models.json" modelsJson;
    }
    // lib.optionalAttrs agents.herdr.enable {
      ".pi/agent/skills/herdr".source = agents.skills.herdr;
      ".pi/agent/extensions/herdr-agent-state.ts".source = agents.herdr.extension "pi";
    };
  };
}
