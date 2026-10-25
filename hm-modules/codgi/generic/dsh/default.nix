{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dsh;
  inherit (lib) types;

  yamlFormat = pkgs.formats.yaml { };

  # Credential reference the dendro routes resolve per request. dsh scrubs
  # `*KEY*` names from agent subprocesses, so the key stays in the harness.
  apiKeyEnv = "DENDRO_API_KEY";
  apiKeyPath = osConfig.codgician.secrets.files."litellm-user-api-key".path;

  # Providers routed through the dendro LiteLLM proxy. `deepseek` is preferred
  # over `azure` because both serve the same model names and only the native
  # route declares reasoning efforts.
  allowedProviders = [
    "chatgpt"
    "claude"
    "deepseek"
    "github"
    "nvidia"
    "vllm"
    "xai"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # dsh sets the wire protocol per route, so each registry mode gets its own
  # route and every model talks to its native LiteLLM surface.
  routes = {
    chat = {
      name = "dendro";
      displayName = "Dendro";
      api = "openai-completions";
    };
    responses = {
      name = "dendro-responses";
      displayName = "Dendro Responses";
      api = "openai-responses";
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
    let
      contextWindow = m.contextWindow or null;
      maxTokens = m.maxOutputTokens or null;
      input = m.input or null;
    in
    {
      id = m.model;
    }
    // lib.optionalAttrs (contextWindow != null) { inherit contextWindow; }
    // lib.optionalAttrs (maxTokens != null) { inherit maxTokens; }
    // lib.optionalAttrs (input != null) { inherit input; }
    // lib.optionalAttrs (m.reasoningEfforts != [ ]) {
      reasoningEfforts = mkReasoningEfforts m.reasoningEfforts;
    };

  mkRoute =
    mode: route:
    let
      models = builtins.filter (m: m.mode == mode) filteredModels;
    in
    lib.optionalAttrs (models != [ ]) {
      ${route.name} = {
        inherit (route) displayName api;
        inherit apiKeyEnv;
        baseURL = "https://dendro.codgician.me/v1";
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
    name = "${cfg.package.name}-dendro";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/dsh" \
        --run ${lib.escapeShellArg "export ${apiKeyEnv}=\"$(<${lib.escapeShellArg apiKeyPath})\""}
    '';
    inherit (cfg.package) meta;
  };
in
{
  options.codgician.codgi.dsh = {
    enable = lib.mkEnableOption "dsh (DeepSeek Harness)";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.llm-agents.dsh;
      defaultText = lib.literalExpression "pkgs.llm-agents.dsh";
      description = ''
        The dsh package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ wrappedPackage ];

    home.file.".dsh/cordis.patch.yml".source = yamlFormat.generate "dsh-cordis.patch.yml" patch;
  };
}
