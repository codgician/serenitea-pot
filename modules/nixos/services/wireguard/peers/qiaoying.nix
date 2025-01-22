{ config, lib }:
with lib.codgician;
{
  name = "qiaoying";
  endpoint = "cd6.codgician.me:51820";
  listenPort = 51820;
  ips = [
    "192.168.254.6/23"
    "fd00:c0d9:1cff::6/48"
  ];
  allowedIPs = [
    "192.168.254.6/32"
    "fd00:c0d9:1cff::6/128"
    "192.168.6.0/24"
    "fd00:c0d9:1c06::/48"
  ];
  privateKeyFile = config.age.secrets.wgQiaoyingPrivateKey.path;
  presharedKeyFile = config.age.secrets.wgPresharedKey.path;
  publicKey = "suqw1v+IDCnupiBU0pHex25qQtb1En2DwofDKoZQrU0=";
  ageFilePaths = builtins.map getAgeSecretPathFromName [
    "wgQiaoyingPrivateKey"
    "wgPresharedKey"
  ];
}
