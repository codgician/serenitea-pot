{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
  inherit (lib) types;

  # Filter text generation models by allowed providers
  allowedProviders = [
    "github"
    "anthropic"
    "nvidia"
  ];

  filteredModels = builtins.filter (
    m: builtins.elem m.provider allowedProviders
  ) osConfig.codgician.models.textGenerationModels;

  # Transform to OpenCode format
  mkOpenCodeModel =
    m:
    {
      name = m.model;
      modalities = {
        input = [
          "text"
          "image"
        ];
        output = [ "text" ];
      };
    }
    // lib.optionalAttrs (m.variants != { }) {
      inherit (m) variants;
    };

  openCodeModels = builtins.listToAttrs (
    map (m: lib.nameValuePair m.model (mkOpenCodeModel m)) filteredModels
  );
in
{
  options.codgician.codgi.opencode = {
    enable = lib.mkEnableOption "opencode";

    web = {
      enable = lib.mkEnableOption "opencode web interface";

      hostname = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Hostname for opencode web interface to listen on.";
      };

      port = lib.mkOption {
        type = types.port;
        default = 3030;
        description = "Port for opencode web interface to listen on.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs.nur.repos.codgician; [ agent-browser ];
    programs.opencode = {
      enable = true;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
      settings = {
        theme = "github";
        plugin = [
          "oh-my-opencode"
        ];
        permission = {
          read = {
            "*" = "allow";
            "*.env" = "deny";
            "*.env.*" = "deny";
            "*.env.example" = "allow";
            "/etc/ssh*" = "deny";
            "/run/agenix*" = "deny";
          };
          edit = "allow";
          external_directory = {
            "*" = "ask";
            "/etc/ssh*" = "deny";
            "/run/agenix*" = "deny";
          };
          bash = {
            "*" = "allow";
            "git *" = "allow";
            "*git push*" = "ask";
            "*sudo*" = "ask";
            "/nix/store*" = "ask";
            "brew*" = "ask";
          };
          list = {
            "*" = "allow";
            "/run/agenix*" = "deny";
          };
        };
        provider.dendro = {
          npm = "@ai-sdk/openai-compatible";
          name = "dendro";
          options.baseURL = "https://dendro.codgician.me/";
          models = openCodeModels;
        };
      };
    };

    xdg.configFile = {
      # Register superpowers + agent-browser skill
      "opencode/skills" = {
        source = pkgs.symlinkJoin {
          name = "opencode-skills";
          paths = [
            "${inputs.superpowers}/skills"
            "${inputs.skills}/skills"
            "${pkgs.nur.repos.codgician.agent-browser.src}/skills"
          ];
        };
        recursive = true;
        force = true;
      };

      # Add override for oh-my-opencode
      "opencode/oh-my-opencode.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/assets/oh-my-opencode.schema.json";
        disabled_skills = [ "dev-browser" ];
        browser_automation_engine = "agent-browser";
        tmux.enabled = true;
        agents = {
          sisyphus.model = "dendro/claude-opus-4-6";
          sisyphus-junior.model = "dendro/claude-sonnet-4-6";
          hephaestus.model = "dendro/gpt-5.4";
          oracle.model = "dendro/gpt-5.4";
          librarian.model = "dendro/gemini-3-flash-preview";
          explore.model = "dendro/gemini-3-flash-preview";
          multimodal-looker.model = "dendro/gemini-3-flash-preview";
          metis.model = "dendro/claude-opus-4-6";
          momus.model = "dendro/gpt-5.4";
          atlas.model = "dendro/claude-sonnet-4-6";
          prometheus.model = "dendro/claude-opus-4-6";
        };
      };
    };
  };
}
