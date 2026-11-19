{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}@args:
let
  cfg = config.codgician.codgi.droid;
  agents = import ../agents.nix args;
  herdrHook = ".factory/hooks/herdr-agent-state.sh";

  mkDroidModel = m: {
    inherit (m) model;
    id = "custom:${m.model}";
    displayName = "${m.model} [Dendro]";
    baseUrl = agents.dendroUrl;
    apiKey = "\${PROVIDER_API_KEY}";
    provider = "generic-chat-completion-api";
  };

  # Droid supports "stdio" for command-based and "http" for URL-based servers.
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
in
{
  options.codgician.codgi.droid = {
    enable = lib.mkEnableOption "Droid configuration";
    package = lib.mkPackageOption pkgs "droid-wrapped" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.llm-agents.agent-browser
    ];

    home.file = {
      # Write to ~/.factory/settings.json (per docs, merged with settings.json)
      ".factory/settings.json".text = builtins.toJSON (
        {
          customModels = map mkDroidModel (
            agents.modelsFrom [
              "github"
              "nvidia"
              "xai"
            ]
          );
          sessionDefaultSettings = {
            model = "custom:claude-opus-5";
            reasoningEffort = "xhigh";
            interactionMode = "auto";
            autonomyLevel = "high";
            autonomyMode = "auto-high";
          };
        }
        // lib.optionalAttrs agents.herdr.enable {
          hooks.SessionStart = [
            (agents.herdr.sessionStart "${config.home.homeDirectory}/${herdrHook}")
          ];
        }
      );

      ".factory/skills".source = pkgs.symlinkJoin {
        name = "droid-skills";
        paths = agents.skillRoots;
      };
    }
    // lib.optionalAttrs agents.herdr.enable {
      ${herdrHook} = agents.herdr.hookFile "droid";
    }
    // lib.optionalAttrs config.codgician.codgi.mcp.enable {
      ".factory/mcp.json".text = builtins.toJSON { inherit mcpServers; };
    };
  };
}
