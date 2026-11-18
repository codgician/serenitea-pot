{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.codgician.codgi."teams-for-linux".enable =
    lib.mkEnableOption "teams-for-linux (Microsoft Teams for Linux)";

  config = lib.mkIf config.codgician.codgi."teams-for-linux".enable {
    home.packages = [ pkgs.teams-for-linux ];

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
