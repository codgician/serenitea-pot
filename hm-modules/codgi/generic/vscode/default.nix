{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.vscode;
in
{
  options.codgician.codgi.vscode = {
    enable = lib.mkEnableOption "Enable Visual Studio Code.";
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = rec {
      enable = true;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      mutableExtensionsDir = false;

      extensions = with pkgs.vscode-marketplace; [
        editorconfig.editorconfig
        tamasfe.even-better-toml
        ms-vscode.hexeditor
        ms-vscode.vscode-copilot-vision
        ms-vscode.vscode-diagnostic-tools
        ms-vscode.remote-explorer
        ms-vscode.remote-repositories
        ms-vscode.remote-server
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-containers
        ms-vscode-remote.vscode-remote-extensionpack
      ] ++ (with pkgs.vscode-marketplace-release; [
        github.copilot
        github.copilot-chat
        github.vscode-pull-request-github
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
        remote.SSH.defaultExtensions = builtins.map (ext: ext.vscodeExtUniqueId) extensions;
      };
    };
  };
}
