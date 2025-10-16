{ config }:
{
  name = "qiaoying";
  domain = "cd.codgician.me";
  listenPort = 51821;
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
  privateKeyFile = config.age.secrets.wg-private-key-qiaoying.path;
  publicKey = "suqw1v+IDCnupiBU0pHex25qQtb1En2DwofDKoZQrU0=";
  persistentKeepalive = 25;
}
