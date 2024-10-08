{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.dev.nix;
in
{
  options.codgician.codgi.dev.nix = {
    enable = lib.mkEnableOption "Enable nix dev environment.";
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
          serverPath = "nil";
        };
      };
    };

    # Language server
    home.packages = with pkgs; [ nil ];
  };
}
