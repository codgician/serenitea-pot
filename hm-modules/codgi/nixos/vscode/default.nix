{ config, lib, ... }:
let
  cfg = config.codgician.codgi.vscode;
  types = lib.types;
in
{
  options.codgician.codgi.vscode = {
    useWayland = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Use Wayland backend for Visual Studio Code.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "code-flags.conf".text = lib.optionalString cfg.useWayland ''
        --ozone-platform=wayland
        --ozone-platform-hint=auto
        --enable-features=WaylandWindowDecorations
      '';
    };
  };
}
