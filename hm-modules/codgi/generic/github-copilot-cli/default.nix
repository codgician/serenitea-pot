{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.github-copilot-cli;

  # Copilot CLI uses "local" for command-based and "http" for URL-based servers,
  # plus a per-server `tools` allowlist.
  mkMcpServer =
    server:
    (
      if server.command != null then
        {
          type = "local";
          inherit (server) command args env;
        }
      else
        {
          type = "http";
          inherit (server) url headers;
        }
    )
    // {
      tools = server.tools or [ "*" ];
    };

  mcpServers = lib.mapAttrs (_: mkMcpServer) (
    lib.filterAttrs (_: server: !(server.disabled or false)) config.programs.mcp.servers
  );

  # MCP config JSON
  mcpConfigJson = builtins.toJSON { inherit mcpServers; };

  # Skills directory combining all skill sources
  skillsDir = pkgs.symlinkJoin {
    name = "copilot-cli-skills";
    paths = [
      "${inputs.superpowers}/skills"
      "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
    ];
  };
in
{
  options.codgician.codgi.github-copilot-cli = {
    enable = lib.mkEnableOption "GitHub Copilot CLI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.github-copilot-cli;
      defaultText = lib.literalExpression "pkgs.github-copilot-cli";
      description = ''
        The GitHub Copilot CLI package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.nur.repos.codgician.agent-browser
    ];

    home.file = {
      # Link skills directory to ~/.copilot/skills
      ".copilot/skills".source = skillsDir;
    }
    // lib.optionalAttrs config.codgician.codgi.mcp.enable {
      # Link MCP config to ~/.copilot/mcp-config.json
      ".copilot/mcp-config.json".text = mcpConfigJson;
    };
  };
}
