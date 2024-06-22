{ config }: {
  name = "suzhou";
  endpoint = "sz.codgician.me";
  listenPort = 51820;
  ips = [ "192.168.254.1/23" "fd00:c0d9:1cff::1/48" ];
  privateKeyFile = config.age.secrets.wgSuzhouPrivateKey.path;
  presharedKeyFile = config.age.secrets.wgSuzhouPresharedKey.path;
  publicKey = "1QYPFw1YL0Px4+41YvBLX4qgXH4KTz9JOqzNbMnlgR8=";
}
