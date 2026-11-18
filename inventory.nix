# Facts that more than one host, module or flake output reads.
# Plain data: no `pkgs`, no module system. `lib/inventory.nix` derives vhosts,
# DNS records and Authelia rules from it.
rec {
  zone = "codgician.me";

  # system:      decides the class (NixOS or nix-darwin) and the package set
  # cudaSupport: build the package set with CUDA
  # roles:       modules from hosts/roles shared with other hosts
  # lan, pve:    addresses other hosts use to reach this one
  hosts = {
    fischl.system = "x86_64-linux";
    focalors = {
      system = "aarch64-linux";
      roles = [ "desktop" ];
    };
    furina.system = "aarch64-darwin";
    jahoda = {
      system = "x86_64-linux";
      roles = [ "desktop" ];
    };
    lumine = {
      system = "aarch64-linux";
      roles = [ "edge" ];
    };
    nahida = {
      system = "x86_64-linux";
      cudaSupport = true;
      lan = "192.168.0.23";
    };
    odette = {
      system = "x86_64-linux";
      roles = [ "desktop" ];
    };
    paimon = {
      system = "x86_64-linux";
      cudaSupport = true;
      lan = "192.168.0.22";
      pve = "192.168.0.21";
    };
    raiden-ei.system = "x86_64-darwin";
    sandrone = {
      system = "aarch64-linux";
      roles = [ "desktop" ];
    };
    wanderer.system = "x86_64-linux";
    xianyun = {
      system = "x86_64-linux";
      roles = [ "edge" ];
    };
    zibai.system = "x86_64-linux";
  };

  # Everything reachable as `<subdomain>.<zone>`; the attribute name is the
  # service's module and vhost name.
  #
  # subdomain: defaults to the attribute name
  # host:      inventory host that runs the service and serves its vhost;
  #            the service's module is active on that host only
  # port:      loopback port of the backend on `host`; services behind a
  #            unix socket omit it and their module sets the vhost's upstream
  # address:   which address of `host` the edge connects to (default `lan`)
  # upstream:  URL of a backend that is not an inventory host, instead of `host`
  # edge:      host that owns the public DNS name and proxies it to the backend;
  #            with neither `host` nor `upstream` only the DNS name exists
  # lanOnly:   the edge keeps the DNS name but does not proxy the service
  # authelia:  require an Authelia session, enforced where the vhost meets the
  #            backend; `users`/`groups` restrict it, otherwise any user passes
  # anubis:    the edge puts Anubis in front
  services = {
    astrolabe.edge = "lumine";
    authelia-main = {
      subdomain = "auth";
      host = "paimon";
      edge = "lumine";
      anubis = true;
    };
    books.edge = "lumine";
    bubbles = {
      upstream = "http://192.168.0.24:1234";
      edge = "lumine";
    };
    # Nothing on paimon answers for this name any more; lumine still proxies it.
    docling-serve = {
      subdomain = "vision";
      upstream = "https://${hosts.paimon.lan}";
      edge = "lumine";
    };
    dsh-web = {
      subdomain = "moongazer";
      host = "nahida";
      port = 3080;
      edge = "lumine";
      # Keeps lumine's nginx.conf in the order it had before this table existed.
      edgeVhost = "moongazer.${zone}";
      authelia.users = [ "codgi" ];
    };
    gitlab = {
      subdomain = "git";
      host = "paimon";
      edge = "lumine";
      anubis = true;
    };
    gns3-server = {
      subdomain = "miliastra";
      host = "paimon";
      port = 3080;
      edge = "lumine";
      authelia.groups = [ "gns3" ];
    };
    grafana = {
      subdomain = "lumenstone";
      host = "paimon";
      edge = "lumine";
      anubis = true;
    };
    hass = {
      upstream = "http://192.168.0.11:8123";
      edge = "lumine";
    };
    jellyfin = {
      subdomain = "fin";
      host = "paimon";
      port = 8096;
      edge = "lumine";
    };
    jupyter = {
      subdomain = "dragonspine";
      host = "nahida";
      port = 8888;
      edge = "lumine";
      authelia = { };
    };
    litellm = {
      subdomain = "dendro";
      host = "lumine";
      port = 5483;
      edge = "lumine";
    };
    matrix-tuwunel = {
      subdomain = "matrix";
      host = "paimon";
      edge = "lumine";
    };
    meshcentral = {
      subdomain = "amt";
      host = "fischl";
      port = 3001;
      edge = "lumine";
      lanOnly = true;
    };
    open-webui = {
      subdomain = "akasha";
      host = "paimon";
      port = 3010;
      edge = "lumine";
    };
    openvscode-server = {
      subdomain = "leyline";
      host = "nahida";
      port = 3000;
      edge = "lumine";
      authelia = { };
    };
    ovis-relay = {
      subdomain = "euthymia";
      host = "lumine";
      port = 8787;
      edge = "lumine";
    };
    saw = {
      upstream = "https://192.168.0.28";
      edge = "lumine";
      authelia = { };
    };
    simulanka = {
      host = "paimon";
      address = "pve";
      edge = "lumine";
    };
    vanarana.edge = "lumine";
    voice.edge = "lumine";
  };
}
