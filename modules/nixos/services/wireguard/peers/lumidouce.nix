{ config }:
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
  privateKeyFile = config.age.secrets.wg-private-key-lumidouce.path;
  publicKey = "1QYPFw1YL0Px4+41YvBLX4qgXH4KTz9JOqzNbMnlgR8=";
  persistentKeepalive = 25;
}
