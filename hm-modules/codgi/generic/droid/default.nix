{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.droid;
  allowedProviders = [
    "github"
    "anthropic"
    "nvidia"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  mkDroidModel = m: {
    inherit (m) model;
    id = "custom:${m.model}";
    displayName = "${m.model} [Dendro]";
    baseUrl = "https://dendro.codgician.me";
    apiKey = "\${PROVIDER_API_KEY}";
    provider = "generic-chat-completion-api";
  };

  # Transform MCP server config to Droid format
  # Droid supports: "stdio" for command-based, "http" for URL-based servers
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

  enabledServers = lib.filterAttrs (
    _: server: !(server.disabled or false)
  ) config.programs.mcp.servers;
  mcpServers = lib.mapAttrs (_: mkMcpServer) enabledServers;
  mcpConfigJson = builtins.toJSON { inherit mcpServers; };

  skillsDir = pkgs.symlinkJoin {
    name = "droid-skills";
    paths = [
      "${inputs.superpowers}/skills"
      "${inputs.skills}/skills"
      "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
    ];
  };
in
{
  options.codgician.codgi.droid = {
    enable = lib.mkEnableOption "Droid configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nur.repos.codgician.droid;
      defaultText = lib.literalExpression "pkgs.nur.repos.codgician.droid";
      description = ''
        The Droid package to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.nur.repos.codgician.agent-browser
    ];

    home.file = {
      # Write to ~/.factory/settings.json (per docs, merged with settings.json)
      ".factory/settings.json".text = builtins.toJSON {
        customModels = map mkDroidModel filteredModels;
        sessionDefaultSettings = {
          model = "custom:claude-opus-4-6";
          reasoningEffort = "high";
          interactionMode = "auto";
          autonomyLevel = "high";
          autonomyMode = "auto-high";
        };
      };

      # Link skills directory to ~/.factory/skills
      ".factory/skills".source = skillsDir;
    }
    // lib.optionalAttrs config.codgician.codgi.mcp.enable {
      # Link MCP config to ~/.factory/mcp.json
      ".factory/mcp.json".text = mcpConfigJson;
    };
  };
}
