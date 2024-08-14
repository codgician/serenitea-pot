{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.vscode;
  types = lib.types;
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

      extensions = with pkgs.vscode-extensions; [
        ms-vscode.hexeditor
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-containers
        github.copilot
        github.copilot-chat
        github.vscode-pull-request-github
      ];
    };
  };
}
