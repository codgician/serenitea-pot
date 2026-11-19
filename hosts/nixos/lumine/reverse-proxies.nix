{ config, lib, ... }:
let
  inherit (lib.codgician) zone;

  # Where the hosts behind lumine are reached
  paimon = "https://192.168.0.22";
  nahida = "https://192.168.0.23";
in
{
  codgician = {
    secrets.files.saw-basic-auth.owner = "nginx";

    services.nginx = {
      landingPage = {
        domain = zone;
        footer = "Our paths will surely cross";
      };

      # Sites of the service modules that paimon and nahida serve
      fronts = {
        authelia-main = {
          proxyPass = paimon;
          anubis = true;
        };
        gitlab = {
          proxyPass = paimon;
          anubis = true;
        };
        gns3-server.proxyPass = paimon;
        grafana = {
          proxyPass = paimon;
          anubis = true;
        };
        jellyfin.proxyPass = paimon;
        jupyter.proxyPass = nahida;
        matrix-tuwunel.proxyPass = paimon;
        open-webui.proxyPass = paimon;
        openvscode-server.proxyPass = nahida;
      };

      # Sites no module declares
      reverseProxies = {
        bubbles = {
          domains = [ "bubbles.${zone}" ];
          proxyPass = "http://192.168.0.24:1234";
        };

        # Nothing on paimon answers for this name any more; the vhost can go
        # with the next change to lumine's nginx configuration.
        docling-serve = {
          domains = [ "vision.${zone}" ];
          proxyPass = paimon;
        };

        hass = {
          domains = [ "hass.${zone}" ];
          proxyPass = "http://192.168.0.11:8123";
        };

        # The dsh Web UI on nahida, which declares the site in its own files.
        # Named after the domain to keep the order of lumine's nginx.conf.
        "moongazer.${zone}" = {
          domains = [ "moongazer.${zone}" ];
          proxyPass = nahida;
          locations."/".extraConfig = ''
            access_log off;
            proxy_buffering off;
          '';
        };

        saw = {
          domains = [ "saw.${zone}" ];
          proxyPass = "https://192.168.0.28";
          # paimon, where Authelia runs, repeats the site and its policy.
          authelia.groups = [ "saw" ];
          locations."/".extraConfig = ''
            client_max_body_size 128M;
            proxy_buffering off;
            include ${config.codgician.secrets.files.saw-basic-auth.path};
          '';
        };

        # Proxmox VE on paimon's management bridge; paimon declares the site
        # in its own files.
        simulanka = {
          domains = [ "simulanka.${zone}" ];
          proxyPass = "https://192.168.0.21";
        };
      };
    };
  };
}
