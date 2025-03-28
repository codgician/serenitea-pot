{ config, lib }:
with lib.codgician;
{
  name = "lumidouce";
  endpoint = "sz.codgician.me:51820";
  listenPort = 51820;
  ips = [
    "192.168.254.1/23"
    "fd00:c0d9:1cff::1/48"
  ];
  allowedIPs = [
    "192.168.254.1/32"
    "fd00:c0d9:1cff::1/128"
    "192.168.0.0/24"
    "fd00:c0d9:1c00::/48"
  ];
  privateKeyFile = config.age.secrets.wgLumidoucePrivateKey.path;
  presharedKeyFile = config.age.secrets.wgPresharedKey.path;
  publicKey = "1QYPFw1YL0Px4+41YvBLX4qgXH4KTz9JOqzNbMnlgR8=";
  ageFilePaths = builtins.map getAgeSecretPathFromName [
    "wgLumidoucePrivateKey"
    "wgPresharedKey"
  ];
  persistentKeepalive = 25;
}
