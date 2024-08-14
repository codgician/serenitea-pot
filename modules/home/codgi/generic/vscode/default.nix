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
        ms-vscode.hexeditor
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-containers
        github.vscode-pull-request-github
      ] ++ (with pkgs.vscode-marketplace-release; [
        github.copilot
        github.copilot-chat
        ms-vscode-remote.remote-ssh
      ]);

      userSettings.editor = {
        fontFamily = "'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace";
        fontSize = 14;
      };
    };
  };
}
