{ config, lib, ... }:

lib.mkMerge [
  {
    # Wireless
    networking.wireless = {
      enable = true;
      scanOnLowSignal = true;
      secretsFile = config.age.secrets.wireless-env.path;
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

      # Make wpa_supplicant try to periodically reconnect on connection lost
      extraConfig = ''
        ap_scan=1
        autoscan=periodic:10
        disable_scan_offload=1
      '';
    };
  }

  (with lib.codgician; mkAgenixConfigs { } [ (getAgeSecretPathFromName "wireless-env") ])
]
