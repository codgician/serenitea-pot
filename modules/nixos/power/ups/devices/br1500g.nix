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
        "serial = 5B2231T57909"
        "vendor = \"American Power Conversion\""
        "ondelay = 90"
        "offdelay = 60"
        "override.battery.charge.low = 20"
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
