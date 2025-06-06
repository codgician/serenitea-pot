{ config }:
{
  name = "xianyun";
  endpoint = "xianyun.codgician.me:51820";
  listenPort = 51820;
  ips = [
    "192.168.254.72/23"
    "fd00:c0d9:1cff::72/48"
  ];
  allowedIPs = [
    "192.168.254.72/32"
    "fd00:c0d9:1cff::72/128"
    "192.168.72.0/24"
    "fd00:c0d9:1c72::/48"
  ];
  privateKeyFile = config.age.secrets.wg-private-key-xianyun.path;
  publicKey = "Uw99L+A6C9/cEzPmowLT8vC+cELdhcXAs61rjHb1hyY=";
  persistentKeepalive = 25;
}
