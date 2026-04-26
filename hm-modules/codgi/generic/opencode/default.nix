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
          "oh-my-openagent"
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
        provider = {
          dendro = {
            npm = "@ai-sdk/openai-compatible";
            name = "dendro";
            options.baseURL = "https://dendro.codgician.me/v1";
            models = openCodeModels;
          };
          dendro-responses = {
            npm = "@ai-sdk/openai";
            name = "dendro-responses";
            options.baseURL = "https://dendro.codgician.me/v1";
            models = openCodeModels;
          };
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

      # Add override for oh-my-openagent
      "opencode/oh-my-openagent.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/refs/heads/dev/assets/oh-my-opencode.schema.json";
        disabled_skills = [
          "dev-browser"
          "playwright"
        ];
        browser_automation_engine = "agent-browser";
        git_master = {
          commit_footer = false;
          include_co_authored_by = false;
        };
        tmux.enabled = true;
        agents = {
          sisyphus.model = "dendro/claude-opus-4-7";
          sisyphus-junior.model = "dendro/claude-sonnet-4-6";
          hephaestus.model = "dendro/gpt-5.5";
          oracle.model = "dendro/gpt-5.5";
          librarian.model = "dendro/gpt-5.4-mini";
          explore.model = "dendro/gpt-5.4-mini";
          multimodal-looker.model = "dendro/gpt-5.3-codex";
          metis.model = "dendro/claude-opus-4-7";
          momus.model = "dendro/gpt-5.5";
          atlas.model = "dendro/claude-sonnet-4-6";
          prometheus.model = "dendro/claude-opus-4-7";
        };
        categories = {
          visual-engineering.model = "dendro/gemini-3.1-pro-preview";
          ultrabrain.model = "dendro/gpt-5.5";
          deep.model = "dendro/gpt-5.5";
          artistry.model = "dendro/gpt-5.5";
          quick.model = "dendro/gpt-5.4-mini";
          unspecified-low.model = "dendro/claude-sonnet-4-6";
          unspecified-high.model = "dendro/claude-opus-4-7";
          writing.model = "dendro/gemini-3-flash-preview";
        };
      };
    };
  };
}
