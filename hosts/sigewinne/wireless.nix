{ config, lib, ... }:

lib.mkMerge [
  {
    # Wireless
    networking.wireless = {
      enable = true;
      secretsFile = config.age.secrets.wirelessEnv.path;
      networks.codgician.pskRaw = "ext:CODGI_PASS";
    };
  }

  (lib.codgician.mkAgenixConfigs { } [ (lib.codgician.secretsDir + "/wirelessEnv.age") ])
]
