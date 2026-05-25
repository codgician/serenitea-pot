{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.pi-coding-agent;

  # Transform MCP server config to oh-my-pi format.
  # Pi (omp) accepts standard MCP server definitions:
  #   - stdio: { command, args?, env? }
  #   - http/sse: { url, headers?, type? }
  # See https://omp.sh/docs/providers and the discovery rules in oh-my-pi
  # which can auto-import sibling tool configs (.claude, .codex, .cursor, ...).
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
      ];
    in
    assert hasCommand || hasUrl;
    assert !(hasCommand && hasUrl);
    baseServer
    // (lib.optionalAttrs hasCommand {
      type = server.type or "stdio";
      inherit (server) command;
      args = server.args or [ ];
      env = server.env or { };
    })
    // (lib.optionalAttrs hasUrl {
      type = server.type or "http";
      inherit (server) url;
      headers = server.headers or { };
    });

  # Filter disabled servers BEFORE transformation, then transform
  enabledServers = lib.filterAttrs (
    _: server: !(server.disabled or false)
  ) config.programs.mcp.servers;
  mcpServers = lib.mapAttrs (_: mkMcpServer) enabledServers;

  # Skills directory combining all skill sources
  skillsDir = pkgs.symlinkJoin {
    name = "pi-coding-agent-skills";
    paths = [
      "${inputs.superpowers}/skills"
      "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
    ];
  };
in
{
  options.codgician.codgi.pi-coding-agent = {
    enable = lib.mkEnableOption "pi-coding-agent (oh-my-pi / omp)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pi-coding-agent;
      defaultText = lib.literalExpression "pkgs.pi-coding-agent";
      description = ''
        The pi-coding-agent package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.nur.repos.codgician.agent-browser
    ];

    home.file = {
      # Link merged skills directory into ~/.omp/skills
      ".omp/skills".source = skillsDir;
    }
    // lib.optionalAttrs config.codgician.codgi.mcp.enable {
      # Provide an explicit MCP servers manifest at ~/.omp/mcp.json.
      # oh-my-pi also auto-discovers servers from sibling tool configs
      # (.claude, .codex, .cursor, ...); this file makes the set explicit
      # so Nix remains the single source of truth.
      ".omp/mcp.json".text = builtins.toJSON { inherit mcpServers; };
    };
  };
}
