{
  config,
  osConfig,
  lib,
  pkgs,
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
        context7 = {
          url = "https://mcp.context7.com/mcp/";
          headers.CONTEXT7_API_KEY = "{file:${osConfig.age.secrets.context7-api-key.path}}";
        };
        github = {
          url = "https://api.githubcopilot.com/mcp/";
          headers.Authorization = "{file:${osConfig.age.secrets.github-auth-header.path}}";
        };
        playwright = {
          command = lib.getExe pkgs.playwright-mcp;
        };
      };
    };
  };
}
