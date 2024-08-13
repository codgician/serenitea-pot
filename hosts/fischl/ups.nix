{ config, lib, ... }:

lib.mkMerge [
  {
    power.ups = {
      enable = true;
      mode = "standalone";
      openFirewall = true;
      users = {
        "admin" = {
          actions = [ "SET" ];
          instcmds = [ "ALL" ];
          passwordFile = config.age.secrets.nutPassword.path;
        };
        "upsmon".passwordFile = config.age.secrets.upsmonPassword.path;
      };

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

      upsd = {
        enable = true;
        listen = [
          { address = "::"; port = 3493; }
        ];
      };
    };
  }

  # Agenix secrets
  (lib.codgician.mkAgenixConfigs "root" [
    (lib.codgician.secretsDir + "/nutPassword.age")
    (lib.codgician.secretsDir + "/upsmonPassword.age")
  ])
]
