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
        context7 = {
          url = "https://mcp.context7.com/mcp";
          headers = {
            # todo: configure in the future
            # CONTEXT7_API_KEY = "{file:${config.age.secrets.context7-api-key.path}}";
          };
        };
      };
    };
  };
}
