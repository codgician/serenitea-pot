# Facts that more than one host, module or flake output reads.
# Plain data: no `pkgs`, no module system. `lib/inventory.nix` holds the
# schema that documents and checks every key, and derives the edge's vhosts,
# the DNS records and the Authelia rules.
rec {
  zone = "codgician.me";
  mail = "bot@${zone}";

  # Host that owns every public name below and proxies it to its backend
  edge = "lumine";

  # Service that is the Authelia portal
  authelia = "authelia-main";

  # Hosts that services run on, with the addresses other hosts reach them at
  hosts = {
    fischl = { };
    lumine = { };
    nahida.lan = "192.168.0.23";
    paimon = {
      lan = "192.168.0.22";
      pve = "192.168.0.21";
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
    # Nothing on paimon answers for this name any more; the entry can go with
    # the next change to lumine's nginx configuration.
    docling-serve = {
      subdomain = "vision";
      upstream = "https://${hosts.paimon.lan}";
    };
    dsh-web = {
      subdomain = "moongazer";
      host = "nahida";
      port = 3080;
      # Keeps the order of lumine's nginx.conf; can go with the next change to it.
      edgeVhost = "moongazer.${zone}";
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
