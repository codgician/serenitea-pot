{ config, lib, ... }:
let
  cfg = config.codgician.power.ups;
in
{
  config.power.ups = lib.mkIf (builtins.elem "lakeview" cfg.devices) {
    ups.lakeview = {
      driver = "nutdrv_qx";
      description = "Lakeview UPS";
      port = "auto";
      directives = [
        "vendorid = 0925"
        "productid = 1234"
        "ondelay = 60"
        "offdelay = 30"
      ];
    };

    upsmon.monitor.lakeview = {
      user = "admin";
      powerValue = 1;
      type = "master";
      passwordFile = config.age.secrets.nutPassword.path;
      system = "lakeview";
    };
  };
}
