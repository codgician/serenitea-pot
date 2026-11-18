{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}@args:
let
  cfg = config.codgician.codgi.claude-code;
  agents = import ../agents.nix args;
  inherit (config.programs.claude-code) configDir;
  herdrHook = "${configDir}/hooks/herdr-agent-state.sh";
in
{
  options.codgician.codgi.claude-code.enable = lib.mkEnableOption "Claude Code";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.llm-agents.agent-browser ];
    # Bypass programs.claude-code.skills: Home Manager inspects those paths
    # during evaluation, which would realize these target-platform sources.
    home.file =
      lib.mapAttrs' (
        name: source: lib.nameValuePair "${configDir}/skills/${name}" { inherit source; }
      ) agents.skills
      // lib.optionalAttrs agents.herdr.enable {
        ${herdrHook} = agents.herdr.hookFile "claude";
      };
    programs.claude-code = {
      enable = true;
      package = agents.packages.claude-code;

      settings = {
        apiKeyHelper = lib.getExe (
          pkgs.writeShellApplication {
            name = "claude-code-api-key-helper";
            text = "[ -r ${agents.apiKeyPath} ] && cat ${agents.apiKeyPath} || exit 1";
          }
        );
        attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
        disallowed_tools = [
          "WebSearch" # Not working for custom endpoint
        ];
        env = {
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          CLAUDE_CODE_EFFORT_LEVEL = "xhigh";
          ANTHROPIC_BASE_URL = agents.dendroUrl;
          ANTHROPIC_MODEL = "claude-opus-5-5[1m]";
          ANTHROPIC_DEFAULT_FABLE_MODEL = "claude-fable-5-2[1m]";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5-5[1m]";
          ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-5-5[1m]";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-5-5";
          CLAUDE_CODE_API_KEY_HELPER_TTL_MS = "86400000";
        };
        permissions = {
          allow = [
            # File operations
            "Read"
            "Edit"
            "Write"
            "Grep"
            "Glob"
            # Safe bash commands
            "Bash(git status:*)"
            "Bash(git diff:*)"
            "Bash(git log:*)"
            "Bash(git branch:*)"
            "Bash(git show:*)"
          ];
          deny = [
            # Sensitive files
            "Read(.env*)"
            "Read(*.pem)"
            "Read(*.key)"
            "Read(/etc/ssh*)"
            "Read(/run/secrets*)"
            # Dangerous commands
            "Bash(rm -rf *)"
            "Bash(sudo *)"
            "Bash(chmod 777 *)"
          ];
        };
        showThinkingSummaries = true;
        effortLevel = "max";
        outputStyle = "Explanatory";
        showTurnDuration = true;
      }
      // lib.optionalAttrs agents.herdr.enable {
        hooks.SessionStart = [ ({ matcher = "*"; } // agents.herdr.sessionStart herdrHook) ];
      };
    };
  };
}
