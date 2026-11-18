{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.codex;
  agents = import ../agents.nix args;

  # CODEX_HOME as programs.codex chooses it, relative to the home directory.
  codexDir =
    if config.home.preferXdgDirectories then
      "${lib.removePrefix config.home.homeDirectory config.xdg.configHome}/codex"
    else
      ".codex";
  codexHome = "${config.home.homeDirectory}/${codexDir}";
  tomlkitPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomlkit ]);
  staticSettings =
    (pkgs.formats.toml { }).generate "codex-static-settings"
      config.programs.codex.settings;
in
{
  options.codgician.codgi.codex.enable = lib.mkEnableOption "Codex";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.llm-agents.agent-browser ];

    programs.codex = {
      enable = true;
      package = agents.packages.codex;
      inherit (agents) skills;
      settings = {
        approval_policy = "never";
        sandbox_mode = "danger-full-access";
        model_provider = "litellm";
        model_providers.litellm = {
          name = "LiteLLM";
          base_url = "${agents.dendroUrl}/v1";
          env_key = "OPENAI_API_KEY";
          wire_api = "responses";
        };
        model = "gpt-6-astra";
      }
      // lib.optionalAttrs agents.herdr.enable { features.hooks = true; };
    };

    # TODO: Replace this workaround with Home Manager's native mutable-settings
    # option when https://github.com/nix-community/home-manager/issues/9397 merges.
    home.file = {
      "${codexDir}/config.toml".enable = false;
    }
    // lib.optionalAttrs agents.herdr.enable {
      "${codexDir}/herdr-agent-state.sh" = agents.herdr.hookFile "codex";
      "${codexDir}/hooks.json".source = (pkgs.formats.json { }).generate "codex-herdr-hooks.json" {
        hooks.SessionStart = [ (agents.herdr.sessionStart "${codexHome}/herdr-agent-state.sh") ];
      };
    };

    home.activation.codexMutableSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe tomlkitPython} ${./merge-settings.py} ${lib.escapeShellArg "${codexHome}/config.toml"} ${lib.escapeShellArg staticSettings}
    '';
  };
}
