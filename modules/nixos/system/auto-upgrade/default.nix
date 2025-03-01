{ config, lib, ... }:
let
  cfg = config.codgician.system.auto-upgrade;
in
{
  options.codgician.system.auto-upgrade = {
    enable = lib.mkEnableOption "System auto upgrading.";
  };

  config = lib.mkIf cfg.enable {
    # Auto upgrade
    system.autoUpgrade = {
      enable = true;
      dates = "03:00";
      operation = "switch";
      randomizedDelaySec = "1h";
      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "05:00";
      };
    };
  };
}
