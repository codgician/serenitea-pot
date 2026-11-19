# Facts that more than one host, module or flake output reads: the
# definitions of the option `codgician.inventory`, which
# `modules/generic/inventory` declares, documents and checks. `config` here
# is the inventory itself.
{ config, ... }:
{
  zone = "codgician.me";
  mail = "bot@${config.zone}";

  # Host that owns the public names below, unless they are `direct`, and
  # proxies them to their backends
  edge = "lumine";

  # Service that is the Authelia portal
  authelia = "authelia-main";

  # Hosts of this flake that other machines refer to, with the addresses they
  # are reached at and their place in the WireGuard mesh
  hosts = {
    fischl = { };
    furina.wireguard = {
      ipv4 = "192.168.254.254";
      ipv6 = "fd00:c0d9:1cff::254";
      publicKey = "90o8pyE8uvb+MAjCvHzxgQKu+yMtbie5cXtSnldoJSk=";
    };
    lumine = {
      public = true;
      wireguard = {
        ipv4 = "192.168.254.64";
        ipv6 = "fd00:c0d9:1cff::64";
        publicKey = "bbtSDKEOb2Odofwwv215lllLckAOkdI0Mh9ZxuiQQUw=";
        port = 51820;
        routes = [
          "192.168.64.0/24"
          "fd00:c0d9:1c64::/48"
        ];
      };
    };
    nahida.lan = "192.168.0.23";
    paimon = {
      lan = "192.168.0.22";
      pve = "192.168.0.21";
    };
    xianyun = {
      public = true;
      ipv4 = "129.28.44.172";
      ipv6 = "2402:4e00:c000:2300:aa68:cd10:e82c:0";
      wireguard = {
        ipv4 = "192.168.254.72";
        ipv6 = "fd00:c0d9:1cff::72";
        publicKey = "Uw99L+A6C9/cEzPmowLT8vC+cELdhcXAs61rjHb1hyY=";
        port = 51820;
        routes = [
          "192.168.72.0/24"
          "fd00:c0d9:1c72::/48"
        ];
      };
    };
  };

  # Machines this flake does not build that its hosts connect to
  peers = {
    lumidouce = {
      subdomain = "sz";
      wireguard = {
        ipv4 = "192.168.254.1";
        ipv6 = "fd00:c0d9:1cff::1";
        publicKey = "1QYPFw1YL0Px4+41YvBLX4qgXH4KTz9JOqzNbMnlgR8=";
        port = 51821;
        routes = [
          "192.168.0.0/24"
          "fd00:c0d9:1c00::/48"
        ];
      };
    };
    qiaoying = {
      subdomain = "cd";
      wireguard = {
        ipv4 = "192.168.254.6";
        ipv6 = "fd00:c0d9:1cff::6";
        publicKey = "suqw1v+IDCnupiBU0pHex25qQtb1En2DwofDKoZQrU0=";
        port = 51821;
        routes = [
          "192.168.6.0/24"
          "fd00:c0d9:1c06::/48"
        ];
      };
    };
  };

  # Everything with a public name `<subdomain>.<zone>`; the attribute name is
  # the name of the service's module and vhost
  services = {
    astrolabe = { };
    authelia-main = {
      subdomain = "auth";
      host = "paimon";
      anubis = true;
    };
    books = { };
    bubbles.upstream = "http://192.168.0.24:1234";
    coturn = {
      subdomain = "turn";
      host = "xianyun";
      direct = true;
    };
    # Nothing on paimon answers for this name any more; the entry can go with
    # the next change to lumine's nginx configuration.
    docling-serve = {
      subdomain = "vision";
      upstream = "https://${config.hosts.paimon.lan}";
    };
    dsh-web = {
      subdomain = "moongazer";
      host = "nahida";
      port = 3080;
      # Keeps the order of lumine's nginx.conf; can go with the next change to it.
      edgeVhost = "moongazer.${config.zone}";
      authelia.users = [ "codgi" ];
    };
    gitlab = {
      subdomain = "git";
      host = "paimon";
      anubis = true;
    };
    gns3-server = {
      subdomain = "miliastra";
      host = "paimon";
      port = 3080;
      authelia.groups = [ "gns3" ];
    };
    grafana = {
      subdomain = "lumenstone";
      host = "paimon";
      anubis = true;
    };
    hass.upstream = "http://192.168.0.11:8123";
    jellyfin = {
      subdomain = "fin";
      host = "paimon";
      port = 8096;
    };
    jupyter = {
      subdomain = "dragonspine";
      host = "nahida";
      port = 8888;
      # No subject was ever declared for this site.
      authelia.anyone = true;
    };
    litellm = {
      subdomain = "dendro";
      host = "lumine";
      port = 5483;
    };
    matrix-tuwunel = {
      subdomain = "matrix";
      host = "paimon";
    };
    meshcentral = {
      subdomain = "amt";
      host = "fischl";
      port = 3001;
      dnsOnly = true;
    };
    open-webui = {
      subdomain = "akasha";
      host = "paimon";
      port = 3010;
    };
    openvscode-server = {
      subdomain = "leyline";
      host = "nahida";
      port = 3000;
      # Meant for `users = [ "leyline" ]`; that rule never reached Authelia.
      authelia.anyone = true;
    };
    ovis-relay = {
      subdomain = "euthymia";
      host = "lumine";
      port = 8787;
    };
    saw = {
      upstream = "https://192.168.0.28";
      # Meant for `groups = [ "saw" ]`; that rule never reached Authelia.
      authelia.anyone = true;
    };
    simulanka = {
      host = "paimon";
      address = "pve";
    };
    vanarana = { };
    voice = { };
  };
}
