{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.mcp;
in
{
  options.codgician.codgi.mcp.enable = lib.mkEnableOption "MCP Servers";

  config = lib.mkIf cfg.enable {
    programs.mcp = {
      enable = true;
      servers = {
        context7.url = "https://mcp.context7.com/mcp/oauth";
        grep_app.url = "https://mcp.grep.app";
        websearch.url = "https://mcp.exa.ai/mcp";
      };
    };

    # Agents not configured through their Home Manager module (droid, antigravity) read programs.mcp.servers themselves.
    programs.claude-code.enableMcpIntegration = true;
    programs.codex.enableMcpIntegration = true;
    programs.github-copilot-cli.enableMcpIntegration = true;
  };
}
