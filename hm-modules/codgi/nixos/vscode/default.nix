{
  config,
  lib,
  osConfig,
  ...
}:
let
  cfg = config.codgician.codgi.vscode;
  types = lib.types;
  useGnomeLibsecret = osConfig.codgician.services.hyprland.enable or false;
  flags =
    lib.optionals cfg.useWayland [
      "--ozone-platform=wayland"
      "--ozone-platform-hint=auto"
      "--enable-features=WaylandWindowDecorations"
    ]
    ++ lib.optional useGnomeLibsecret "--password-store=gnome-libsecret";
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
    xdg.configFile."code-flags.conf".text = lib.optionalString (flags != [ ]) (
      lib.concatStringsSep "\n" flags + "\n"
    );
  };
}
