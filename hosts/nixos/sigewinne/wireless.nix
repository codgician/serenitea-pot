{ config, lib, ... }:

lib.mkMerge [
  {
    # Wireless
    networking.wireless = {
      enable = true;
      scanOnLowSignal = true;
      secretsFile = config.age.secrets.wirelessEnv.path;
      networks = {
        codgician = {
          priority = 100;
          pskRaw = "ext:CODGI_PASS";
        };
        codgacy = {
          priority = 10;
          pskRaw = "ext:CODGI_PASS";
        };
      };
    };
  }

  (lib.codgician.mkAgenixConfigs { } [ (lib.codgician.secretsDir + "/wirelessEnv.age") ])
]
