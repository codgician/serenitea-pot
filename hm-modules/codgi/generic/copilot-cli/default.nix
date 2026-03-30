{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.copilot-cli;

  # Transform MCP server config to Copilot CLI format
  # Copilot CLI supports: "local"/"stdio" for command-based, "http"/"sse" for URL-based servers
  mkMcpServer =
    server:
    let
      hasCommand = server ? command;
      hasUrl = server ? url;
      baseServer = builtins.removeAttrs server [
        "disabled"
        "command"
        "args"
        "env"
        "url"
        "headers"
        "type"
        "tools"
      ];
    in
    # Assert exactly one transport source (command xor url)
    assert hasCommand || hasUrl;
    assert !(hasCommand && hasUrl);
    baseServer
    // (lib.optionalAttrs hasCommand {
      type = server.type or "local";
      inherit (server) command;
      args = server.args or [ ];
      env = server.env or { };
    })
    // (lib.optionalAttrs hasUrl {
      type = server.type or "http";
      inherit (server) url;
      headers = server.headers or { };
    })
    // {
      tools = server.tools or [ "*" ];
    };

  # Filter disabled servers BEFORE transformation, then transform
  enabledServers = lib.filterAttrs (
    _: server: !(server.disabled or false)
  ) config.programs.mcp.servers;
  mcpServers = lib.mapAttrs (_: mkMcpServer) enabledServers;

  # MCP config JSON
  mcpConfigJson = builtins.toJSON { inherit mcpServers; };

  # Skills directory combining all skill sources
  skillsDir = pkgs.symlinkJoin {
    name = "copilot-cli-skills";
    paths = [
      "${inputs.superpowers}/skills"
      "${inputs.skills}/skills"
      "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
    ];
  };
in
{
  options.codgician.codgi.copilot-cli = {
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
