{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.dsh;
  agents = import ../agents.nix args;

  # Resolve the credential at launch without putting it in the Nix store.
  apiKeyEnv = "DENDRO_API_KEY";

  # `deepseek` is preferred over `azure` because both serve the same model
  # names and only the native route declares reasoning efforts.
  dendroModels = agents.modelsFrom [
    "chatgpt"
    "claude"
    "deepseek"
    "github"
    "nvidia"
    "vllm"
    "xai"
  ];

  # dsh sets the wire protocol per route, so each registry mode gets its own
  # route and every model talks to its native LiteLLM surface.
  routes = {
    chat = {
      name = "dendro";
      displayName = "Dendro";
    };
    responses = {
      name = "dendro-responses";
      displayName = "Dendro Responses";
    };
  };

  # dsh thinking levels; registry efforts map onto them by name, except the
  # registry's `none`, which is dsh's `off`.
  dshLevels = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  effortToLevel = effort: if effort == "none" then "off" else effort;

  # Level -> exact effort string sent upstream; only efforts the model defines.
  mkReasoningEfforts =
    efforts:
    builtins.listToAttrs (
      map (effort: lib.nameValuePair (effortToLevel effort) effort) (
        builtins.filter (effort: effort == "none" || builtins.elem effort dshLevels) efforts
      )
    );

  # Registry model -> dsh model entry. `id` matches the LiteLLM model name.
  mkDshModel =
    m:
    {
      id = m.model;
    }
    // agents.modelLimits m
    // lib.optionalAttrs ((m.input or null) != null) { inherit (m) input; }
    // lib.optionalAttrs (m.reasoningEfforts != [ ]) {
      reasoningEfforts = mkReasoningEfforts m.reasoningEfforts;
    };

  mkRoute =
    mode: route:
    let
      models = builtins.filter (m: m.mode == mode) dendroModels;
    in
    lib.optionalAttrs (models != [ ]) {
      ${route.name} = {
        inherit (route) displayName;
        inherit apiKeyEnv;
        api = agents.modeToApi.${mode};
        baseURL = "${agents.dendroUrl}/v1";
        models = map mkDshModel models;
      };
    };

  # Home-level patch layer, applied over every profile's bundles and patch.
  patch = [
    {
      id = "llm-pi-ai";
      config.providers = lib.concatMapAttrs mkRoute routes;
    }
    {
      id = "agent-default-model";
      config = {
        provider = routes.chat.name;
        model = "claude-opus-5.5";
        reasoningEffort = "medium";
      };
    }
  ];

  wrappedPackage = pkgs.symlinkJoin {
    name = "${pkgs.llm-agents.dsh.name}-dendro";
    paths = [ pkgs.llm-agents.dsh ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/dsh" \
        --run ${lib.escapeShellArg ''
          if ! ${apiKeyEnv}="$(<${lib.escapeShellArg agents.apiKeyPath})" || [ -z "${"$" + apiKeyEnv}" ]; then
            echo 'dsh: cannot load the Dendro API key' >&2
            exit 1
          fi
          export ${apiKeyEnv}
        ''}
    '';
    inherit (pkgs.llm-agents.dsh) meta;
  };
in
{
  options.codgician.codgi.dsh = {
    enable = lib.mkEnableOption "dsh (DeepSeek Harness)";

    wrappedPackage = lib.mkOption {
      type = lib.types.package;
      default = wrappedPackage;
      readOnly = true;
      internal = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.wrappedPackage ];

    home.file.".dsh/cordis.patch.yml".source =
      (pkgs.formats.yaml { }).generate "dsh-cordis.patch.yml"
        patch;
  };
}
