{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.vscode;
  types = lib.types;
in
{
  options.codgician.codgi.vscode = {
    enable = lib.mkEnableOption "Enable Visual Studio Code.";

    useWayland = lib.mkOption {
      type = types.bool;
      default = true;
      description = ''Use Wayland backend for Visual Studio Code.'';
    };

  };

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = true;
      mutableExtensionsDir = true;
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
