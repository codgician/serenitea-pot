{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.claude-code;

  # Transform MCP server config to Claude Code format
  # Supports both stdio ({ command, args?, env? }) and http ({ url, headers? })
  mkMcpServer =
    server:
    (builtins.removeAttrs server [ "disabled" ])
    // (lib.optionalAttrs (server ? url) { type = "http"; })
    // (lib.optionalAttrs (server ? command) { type = "stdio"; });

  # Transform all MCP servers
  mcpServers = lib.mapAttrs (_: mkMcpServer) config.programs.mcp.servers;
in
{
  options.codgician.codgi.claude-code = {
    enable = lib.mkEnableOption "Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code-bin;
      defaultText = lib.literalExpression "pkgs.claude-code-bin";
      description = ''
        The Claude Code package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs.nur.repos.codgician; [ agent-browser ];
    programs.claude-code = {
      enable = true;
      package = cfg.package;

      # MCP integration
      mcpServers = lib.mkIf config.codgician.codgi.mcp.enable mcpServers;

      skillsDir = pkgs.symlinkJoin {
        name = "claude-code-skills";
        paths = [
          "${inputs.superpowers}/skills"
          "${inputs.skills}/skills"
          "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
        ];
      };

      settings = {
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
            "Read(/run/agenix*)"
            # Dangerous commands
            "Bash(rm -rf *)"
            "Bash(sudo *)"
            "Bash(chmod 777 *)"
          ];
        };
      };
    };
  };
}
