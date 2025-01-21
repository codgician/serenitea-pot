{ config, lib }:
with lib.codgician;
{
  name = "lumine";
  endpoint = "lumine.codgician.me:51820";
  listenPort = 51820;
  ips = [
    "192.168.254.64/23"
    "fd00:c0d9:1cff::64/48"
  ];
  allowedIPs = [
    "192.168.254.64/32"
    "fd00:c0d9:1cff::64/128"
    "192.168.64.0/24"
    "fd00:c0d9:1c64::/48"
  ];
  privateKeyFile = config.age.secrets.wgLuminePrivateKey.path;
  presharedKeyFile = config.age.secrets.wgPresharedKey.path;
  publicKey = "bbtSDKEOb2Odofwwv215lllLckAOkdI0Mh9ZxuiQQUw=";
  ageFilePaths = builtins.map getAgeSecretPathFromName [
    "wgLuminePrivateKey"
    "wgPresharedKey"
  ];
}
