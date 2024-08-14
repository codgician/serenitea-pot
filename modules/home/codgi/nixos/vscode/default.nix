{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.vscode;
  types = lib.types;
in
{
  imports = lib.codgician.getNixFilePaths ./envs;

  options.codgician.codgi.vscode = {
    enable = lib.mkEnableOption "Enable Visual Studio Code.";

    useWayland = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Use Wayland backend for Visual Studio Code.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      mutableExtensionsDir = false;

      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        ms-vscode.hexeditor
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-containers
        github.copilot
        github.copilot-chat
        github.vscode-pull-request-github
      ];
    };

    xdg.configFile = {
      "code-flags.conf".text = lib.optionalString cfg.useWayland ''
        --ozone-platform=wayland
        --ozone-platform-hint=auto
        --enable-features=WaylandWindowDecorations
      '';
    };
  };
}
