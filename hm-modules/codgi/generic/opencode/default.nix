args@{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
in
{
  options.codgician.codgi.opencode = {
    enable = lib.mkEnableOption "opencode";
  };

  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = config.codgician.codgi.mcp.enable;
      settings = {
        theme = "github";
        plugin = [ "oh-my-opencode" ];
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

    # Add override for oh-my-opencode
    xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
      agents = {
        Sisyphus.model = "dendro/claude-opus-4.5";
        librarian.model = "dendro/claude-sonnet-4.5";
        explore.model = "dendro/gemini-3-flash-preview";
        oracle.model = "dendro/gpt-5.2";
        frontend-ui-ux-engineer.model = "dendro/gemini-3-pro-preview";
        document-writer.model = "dendro/gemini-3-pro-preview";
        multimodal-looker.model = "dendro/gemini-3-flash-preview";
      };
    };
  };
}
