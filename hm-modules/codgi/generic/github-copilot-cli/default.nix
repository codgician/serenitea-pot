{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.github-copilot-cli;
  agents = import ../agents.nix args;
  inherit (config.programs.github-copilot-cli) configDir;
  herdrHook = "${configDir}/hooks/herdr-agent-state.sh";
in
{
  options.codgician.codgi.github-copilot-cli = {
    enable = lib.mkEnableOption "GitHub Copilot CLI";
    package = lib.mkPackageOption pkgs [ "llm-agents" "copilot-cli" ] { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.llm-agents.agent-browser ];
    home.file = {
      # Own the directory symlink so Home Manager can replace stale generations.
      "${configDir}/skills".source = pkgs.symlinkJoin {
        name = "copilot-cli-skills";
        paths = agents.skillRoots;
      };
    }
    // lib.optionalAttrs agents.herdr.enable {
      ${herdrHook} = agents.herdr.hookFile "copilot";
      "${configDir}/settings.json".source =
        (pkgs.formats.json { }).generate "copilot-herdr-settings.json"
          {
            hooks.SessionStart = [
              {
                type = "command";
                bash = "bash '${herdrHook}'";
                timeoutSec = 10;
              }
            ];
          };
    };
    programs.github-copilot-cli = {
      enable = true;
      inherit (cfg) package;
    };
  };
}
