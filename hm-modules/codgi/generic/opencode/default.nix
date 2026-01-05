{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
  allModels =
    (import ../../../../modules/nixos/services/litellm/models.nix {
      inherit lib pkgs outputs;
    }).all;

  models = lib.listToAttrs (
    builtins.map (m: lib.nameValuePair m.model_name { name = m.model_name; }) (
      lib.filter (
        m:
        builtins.elem (m.model_info.mode or "") [
          "chat"
          "responses"
        ]
      ) allModels
    )
  );
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
        provider.dendro = {
          npm = "@ai-sdk/openai-compatible";
          name = "dendro";
          options.baseURL = "https://dendro.codgician.me/";
          inherit models;
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
