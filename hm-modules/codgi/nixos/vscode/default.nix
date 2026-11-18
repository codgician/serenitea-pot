{ config, lib, ... }:
{
  config = lib.mkIf config.codgician.codgi.vscode.enable {
    xdg.configFile."code-flags.conf".text = ''
      --ozone-platform=wayland
      --ozone-platform-hint=auto
      --enable-features=WaylandWindowDecorations
    '';
  };
}
