{ config }:
{
  name = "lumine";
  domain = "lumine.codgician.me";
  port = 51820;
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
  privateKeyFile = config.age.secrets.wg-private-key-lumine.path;
  publicKey = "bbtSDKEOb2Odofwwv215lllLckAOkdI0Mh9ZxuiQQUw=";
  persistentKeepalive = 25;
}
