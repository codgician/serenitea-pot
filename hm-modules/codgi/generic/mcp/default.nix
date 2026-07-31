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
  };
}
