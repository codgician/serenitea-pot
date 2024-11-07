{ config, lib, ... }:
let
  cfg = config.codgician.power.ups;
in
{
  config.power.ups = lib.mkIf (builtins.elem "br1500g" cfg.devices) {
    ups.br1500g = {
      driver = "usbhid-ups";
      description = "APC Back-UPS RS 1500G";
      port = "auto";
      directives = [
        "vendorid = 051D"
        "productid = 0002"
        "vendor = \"American Power Conversion\""
        "ondelay = ${toString cfg.onDelay}"
        "offdelay = ${toString cfg.offDelay}"
        "override.battery.charge.low = ${toString cfg.batteryLow}"
      ];
    };

    upsmon.monitor.br1500g = {
      user = "admin";
      powerValue = 1;
      type = "master";
      passwordFile = config.age.secrets.nutPassword.path;
      system = "br1500g";
    };
  };
}
