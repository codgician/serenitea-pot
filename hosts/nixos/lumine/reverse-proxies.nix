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

    services.anubis.enable = true;

    services.nginx = {
      enable = true;
      openFirewall = true;

      landingPage = {
        domain = zone;
        footer = "Our paths will surely cross";
      };

      # Sites lumine is the public entry of
      reverseProxies = {
        authelia-main = {
          proxyPass = paimon;
          anubis = true;
        };

        bubbles.proxyPass = "http://192.168.0.24:1234";

        # Nothing on paimon answers for this name any more; the vhost can go
        # with the next change to lumine's nginx configuration.
        docling-serve.proxyPass = paimon;

        dsh-web = {
          proxyPass = nahida;
          locations."/".extraConfig = ''
            access_log off;
            proxy_buffering off;
          '';
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

        hass.proxyPass = "http://192.168.0.11:8123";

        jellyfin.proxyPass = paimon;
        jupyter.proxyPass = nahida;
        matrix-tuwunel.proxyPass = paimon;
        open-webui.proxyPass = paimon;
        openvscode-server.proxyPass = nahida;

        saw = {
          proxyPass = "https://192.168.0.28";
          locations."/".extraConfig = ''
            client_max_body_size 128M;
            proxy_buffering off;
            include ${config.codgician.secrets.files.saw-basic-auth.path};
          '';
        };

        # Proxmox VE on paimon's management bridge
        simulanka.proxyPass = "https://192.168.0.21";
      };
    };
  };
}
