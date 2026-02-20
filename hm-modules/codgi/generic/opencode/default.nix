args@{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
  inherit (lib) types;
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
            "sudo*" = "ask";
            "/nix/store*" = "ask";
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
          models = (import ./models.nix args).all;
        };
      };
    };

    xdg.configFile = {
      # Register superpowers + agent-browser skill
      "opencode/skill" = {
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
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
        agents = {
          sisyphus.model = "dendro/claude-opus-4.6";
          librarian.model = "dendro/claude-sonnet-4.5";
          explore.model = "dendro/gemini-3-flash-preview";
          oracle.model = "dendro/gpt-5.2";
          frontend-ui-ux-engineer.model = "dendro/gemini-3.1-pro-preview";
          document-writer.model = "dendro/gemini-3.1-pro-preview";
          multimodal-looker.model = "dendro/gemini-3-flash-preview";
        };
      };
    };
  };
}
