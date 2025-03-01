{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dev.nix;
in
{
  options.codgician.codgi.dev.nix = {
    enable = lib.mkEnableOption "Nix dev environment.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      extensions = with pkgs.vscode-marketplace; [
        jnoortheen.nix-ide
      ];

      userSettings = {
        "[nix]".editor.tabSize = 2;
        nix = {
          enableLanguageServer = true;
          serverPath = "nixd";
          serverSettings.nixd = {
            formatting.command = [ "nixfmt " ];
          };
        };
      };
    };

    # Language server
    home.packages = with pkgs; [ nixd ];
  };
}
