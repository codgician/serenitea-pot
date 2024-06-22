{ config }: {
  name = "lumine";
  endpoint = "lumine.codgician.me";
  listenPort = 51820;
  ips = [ "192.168.254.100/23" "fd00:c0d9:1cff::100/48" ];
  privateKeyFile = config.age.secrets.wgLuminePrivateKey.path;
  presharedKeyFile = config.age.secrets.wgLuminePresharedKey.path;
  publicKey = "xtAnR4YU1zUW3uzV9DnUEUnbfY8qkrOpUFTEj5Pf3Hk=";
}
