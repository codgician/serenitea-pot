{ config }:
{
  name = "furina";
  domain = null;
  port = null;
  ips = [
    "192.168.254.254/23"
    "fd00:c0d9:1cff::254/48"
  ];
  allowedIPs = [
    "192.168.254.254/32"
    "fd00:c0d9:1cff::254/128"
  ];
  privateKeyFile = config.age.secrets.wg-private-key-furina.path;
  publicKey = "90o8pyE8uvb+MAjCvHzxgQKu+yMtbie5cXtSnldoJSk=";
  persistentKeepalive = 25;
}
