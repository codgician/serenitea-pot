{ config, lib, ... }:

lib.mkMerge [
  {
    power.ups = {
      enable = true;
      mode = "standalone";
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
        user = "nut";
        powerValue = 1;
        type = "master";
        passwordFile = config.age.secrets.nutPassword.path;
        system = "lakeview";
      };
    };
  }

  # Agenix secrets
  (lib.codgician.mkAgenixConfigs "root" [ (lib.codgician.secretsDir + "/nutPassword.age") ])
]
