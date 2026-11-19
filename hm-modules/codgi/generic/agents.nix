# Values shared by the LLM agent modules. Not a module: import it with the
# module arguments.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (config.codgician) codgi;
  herdrIntegrations = "${pkgs.llm-agents.herdr}/share/herdr/integrations";
  skillSources = {
    agent-browser = pkgs.llm-agents.agent-browser.src;
  }
  // lib.optionalAttrs codgi.herdr.enable { herdr = pkgs.llm-agents.herdr.src; };
in
rec {
  packages = {
    claude-code = pkgs.llm-agents.claude-code;
    codex = pkgs.codex-wrapped;
    droid = pkgs.droid-wrapped;
    github-copilot-cli = pkgs.llm-agents.copilot-cli;
    oh-my-pi = pkgs.nur.repos.codgician.oh-my-pi-bin;
    pi-coding-agent = pkgs.llm-agents.pi;
  };
  enabledPackages = lib.attrValues (lib.filterAttrs (name: _: codgi.${name}.enable) packages);

  # The LiteLLM proxy; the key is read at run time and never enters the store.
  # The litellm module names the site; a macOS host cannot read a NixOS module.
  dendroUrl = "https://dendro.${lib.codgician.zone}";
  apiKeyPath = osConfig.codgician.secrets.files."litellm-user-api-key".path;
  apiKeyCommand = "!cat ${apiKeyPath}";

  textModels = osConfig.codgician.models.textGenerationModels;
  modelsFrom = providers: builtins.filter (m: builtins.elem m.provider providers) textModels;

  # Registry mode -> wire API, so each model talks to its native LiteLLM
  # surface instead of LiteLLM's chat<->responses bridge.
  modeToApi = {
    chat = "openai-completions";
    responses = "openai-responses";
  };

  modelLimits =
    m:
    lib.filterAttrs (_: limit: limit != null) {
      contextWindow = m.contextWindow or null;
      maxTokens = m.maxOutputTokens or null;
    };

  # Skill name -> directory, and the directories holding one folder per skill.
  skills = lib.mapAttrs (name: src: "${src}/skills/${name}") skillSources;
  skillRoots = map (src: "${src}/skills") (lib.attrValues skillSources);

  herdr = {
    inherit (codgi.herdr) enable;
    hookFile = agent: {
      source = "${herdrIntegrations}/${agent}/herdr-agent-state.sh";
      executable = true;
    };
    extension = agent: "${herdrIntegrations}/${agent}/herdr-agent-state.ts";
    # SessionStart entry in the hook format Claude Code, Codex and Droid share.
    sessionStart = hook: {
      hooks = [
        {
          type = "command";
          command = "bash '${hook}' session";
          timeout = 10;
        }
      ];
    };
  };
}
