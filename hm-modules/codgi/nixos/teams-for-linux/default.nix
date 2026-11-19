{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.teams-for-linux;
in
{
  options.codgician.codgi.teams-for-linux = {
    enable = lib.mkEnableOption "teams-for-linux (Microsoft Teams for Linux)";
    package = lib.mkPackageOption pkgs "teams-for-linux" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

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
