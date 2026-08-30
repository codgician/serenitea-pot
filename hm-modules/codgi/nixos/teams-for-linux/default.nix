{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi."teams-for-linux";
in
{
  options.codgician.codgi."teams-for-linux" = {
    enable = lib.mkEnableOption "teams-for-linux (Microsoft Teams for Linux)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.teams-for-linux;
      defaultText = lib.literalExpression "pkgs.teams-for-linux";
      description = "The teams-for-linux package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Shared configuration across all machines.
    xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
      appIconType = "light";
      auth = {
        intune.enabled = true;
        webauthn.enabled = true;
      };
      disableGpu = false;
      download.enabled = true;
      enableIncomingCallToast = true;
      graphApi.enabled = true;
      quickChat = {
        enabled = true;
        shortcut = "CommandOrControl+Alt+Q";
      };
    };
  };
}
