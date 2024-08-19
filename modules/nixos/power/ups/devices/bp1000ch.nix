{ config, lib, ... }:
let
  cfg = config.codgician.power.ups;
in
{
  config.power.ups = lib.mkIf (builtins.elem "bp1000ch" cfg.devices) {
    ups.bp1000ch = {
      driver = "nutdrv_qx";
      description = "APC Back-UPS BP 1000CH";
      port = "auto";
      directives = [
        "protocol = voltronic-qs"
        "ondelay = 90"
        "offdelay = 60"
        "port = /dev/ttyS0"
      ];
    };

    upsmon.monitor.bp1000ch = {
      user = "admin";
      powerValue = 1;
      type = "master";
      passwordFile = config.age.secrets.nutPassword.path;
      system = "bp1000ch";
    };
  };
}
