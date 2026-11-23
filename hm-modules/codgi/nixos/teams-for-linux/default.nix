{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.teams-for-linux;
  useGnomeLibsecret = osConfig.codgician.services.hyprland.enable or false;
  # Electron falls back to the basic plaintext store on Hyprland unless gnome-libsecret is requested.
  package =
    if useGnomeLibsecret then
      pkgs.symlinkJoin {
        name = "${cfg.package.name}-gnome-libsecret";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/teams-for-linux \
            --add-flags "--password-store=gnome-libsecret"
        '';
      }
    else
      cfg.package;
in
{
  options.codgician.codgi.teams-for-linux = {
    enable = lib.mkEnableOption "teams-for-linux (Microsoft Teams for Linux)";
    package = lib.mkPackageOption pkgs "teams-for-linux" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
      auth = {
        intune.enabled = true;
        webauthn.enabled = true;
      };
      download.enabled = true;
      graphApi.enabled = true;
      incomingCalls.toast = true;
      performance.disableGpu = false;
      quickChat = {
        enabled = true;
        shortcut = "CommandOrControl+Alt+Q";
      };
      tray.iconType = "light";
    };
  };
}
