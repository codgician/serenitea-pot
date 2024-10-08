{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.vscode;
in
{
  options.codgician.codgi.vscode = {
    enable = lib.mkEnableOption "Enable Visual Studio Code.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      mutableExtensionsDir = false;

      extensions = with pkgs.vscode-marketplace; [
        editorconfig.editorconfig
        github.vscode-pull-request-github
        tamasfe.even-better-toml
        ms-vscode.hexeditor
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-containers
      ] ++ (with pkgs.vscode-marketplace-release; [
        github.copilot
        github.copilot-chat
        ms-vscode-remote.remote-ssh
      ]);

      userSettings = {
        editor = {
          fontFamily = "'Cascadia Code NF', 'Cascadia Code', monospace";
          fontSize = 14;
        };
        terminal.integrated = {
          fontFamily = "'Cascadia Mono PL', 'Cascadia Mono', monospace";
          fontSize = 14;
        };
      };
    };
  };
}
