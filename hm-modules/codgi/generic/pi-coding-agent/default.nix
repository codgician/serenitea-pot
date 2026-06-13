{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.pi-coding-agent;

  # Transform MCP servers to oh-my-pi format (stdio / http).
  # See https://omp.sh/docs/providers.
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

  mcpServers = lib.mapAttrs (_: mkMcpServer) (
    lib.filterAttrs (_: server: !(server.disabled or false)) config.programs.mcp.servers
  );

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
