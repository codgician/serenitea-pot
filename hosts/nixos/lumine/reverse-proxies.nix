{ pkgs, ... }:
{
  codgician = {
    containers = {
      comfyui.reverseProxy = {
        enable = true;
        domains = [ "vanarana.codgician.me" ];
        proxyPass = "https://192.168.0.22";
      };
    };

    services = {
      authelia.instances.main = {
        domain = "auth.codgician.me";
        reverseProxy = {
          enable = true;
          proxyPass = "https://192.168.0.22";
        };
      };

      code-server.reverseProxy = {
        enable = true;
        domains = [ "leyline.codgician.me" ];
        proxyPass = "https://192.168.0.8";
      };

      dendrite = {
        domain = "matrix.codgician.me";
        reverseProxy = {
          enable = true;
          elementWeb = true;
          proxyPass = "https://192.168.0.22";
        };
      };

      gitlab = {
        host = "git.codgician.me";
        reverseProxy = {
          enable = true;
          proxyPass = "https://192.168.0.22";
        };
      };

      grafana.reverseProxy = {
        enable = true;
        domains = [ "lumenstone.codgician.me" ];
        proxyPass = "http://192.168.0.22";
      };

      jellyfin.reverseProxy = {
        enable = true;
        domains = [ "fin.codgician.me" ];
        proxyPass = "https://192.168.0.22";
      };

      jupyter.reverseProxy = {
        enable = true;
        domains = [ "dragonspine.codgician.me" ];
        proxyPass = "https://192.168.0.8";
      };

      open-webui.reverseProxy = {
        enable = true;
        domains = [ "akasha.codgician.me" ];
        proxyPass = "https://192.168.0.22";
      };

      meshcentral.reverseProxy = {
        enable = true;
        domains = [ "amt.codgician.me" ];
        proxyPass = "https://192.168.0.10";
      };

      nginx = {
        enable = true;
        openFirewall = true;
        reverseProxies = {
          "bubbles.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "bubbles.codgician.me" ];
            locations."/".passthru.proxyPass = "http://192.168.0.9:1234";
          };

          "hass.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "hass.codgician.me" ];
            locations."/".passthru.proxyPass = "http://192.168.0.6:8123";
          };

          "pve.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "pve.codgician.me" ];
            locations."/".passthru.proxyPass = "https://192.168.0.21";
          };

          "saw.codgician.me" = {
            enable = true;
            authelia.enable = true;
            https = true;
            domains = [ "saw.codgician.me" ];
            locations."/".passthru = {
              proxyPass = "https://192.168.0.28";
              extraConfig = ''
                client_max_body_size 128M;
                proxy_buffering off;
              '';
            };
          };

          "codgician.me" = {
            enable = true;
            https = true;
            domains = [
              "codgician.me"
              "*.codgician.me"
            ];
            locations."/".passthru.root = import ./lumine-web.nix { inherit pkgs; };
          };
        };
      };
    };
  };
}
