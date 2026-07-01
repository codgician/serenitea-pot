{
  config,
  lib,
  pkgs,
  inputs,
  osConfig,
  ...
}:
let
  cfg = config.codgician.codgi.claude-code;

  # Transform MCP servers to Claude Code format (stdio / http).
  mkMcpServer =
    server:
    if server.command != null then
      {
        type = "stdio";
        inherit (server) command args env;
      }
    else
      {
        type = "http";
        inherit (server) url headers;
      };

  mcpServers = lib.mapAttrs (_: mkMcpServer) config.programs.mcp.servers;

  skills = lib.codgician.mergeFolders [
    "${inputs.superpowers}/skills"
    "${inputs.skills}/skills"
    "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
  ];
in
{
  options.codgician.codgi.claude-code = {
    enable = lib.mkEnableOption "Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code;
      defaultText = lib.literalExpression "pkgs.claude-code";
      description = ''
        The Claude Code package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs.nur.repos.codgician; [ agent-browser ];
    programs.claude-code = {
      enable = true;
      inherit (cfg) package;

      mcpServers = lib.mkIf config.codgician.codgi.mcp.enable mcpServers;

      inherit skills;

      settings = {
        apiKeyHelper =
          let
            inherit (osConfig.codgician.secrets.templates."litellm-user-api-key") path;
          in
          lib.getExe (
            pkgs.writeShellApplication {
              name = "claude-code-api-key-helper";
              text = "[ -r ${path} ] && cat ${path} || exit 1";
            }
          );
        env = {
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          CLAUDE_CODE_EFFORT_LEVEL = "max";
          ANTHROPIC_BASE_URL = "https://dendro.codgician.me";
          ANTHROPIC_MODEL = "claude-opus-4-8";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5";
          ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5";
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
      };
    };
  };
}
