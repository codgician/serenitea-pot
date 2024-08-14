{ config, lib, ... }:

lib.mkMerge [
  {
    # Wireless
    networking.wireless = {
      enable = true;
      environmentFile = config.age.secrets.wirelessEnv.path;
      networks.codgician.psk = "@CODGI_PASS@";
    };
  }

  (lib.codgician.mkAgenixConfigs "root" [ (lib.codgician.secretsDir + "/wirelessEnv.age") ])
]
