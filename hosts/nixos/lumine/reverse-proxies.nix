{ pkgs, ... }:
{
  codgician = {
    containers.comfyui.reverseProxy = {
      enable = true;
      domains = [ "vanarana.codgician.me" ];
      proxyPass = "https://192.168.0.22";
    };

    services = {
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
          proxyPass = "https://192.168.0.7";
        };
      };

      jellyfin.reverseProxy = {
        enable = true;
        domains = [ "fin.codgician.me" ];
        proxyPass = "https://192.168.0.22";
      };

      open-webui.reverseProxy = {
        enable = true;
        domains = [ "akasha.codgician.me" ];
        proxyPass = "https://192.168.0.22";
      };

      nginx = {
        enable = true;
        openFirewall = true;
        reverseProxies = {
          "amt.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "amt.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "books.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "books.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "bubbles.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "bubbles.codgician.me" ];
            locations."/".proxyPass = "http://192.168.0.9:1234";
          };

          "hass.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "hass.codgician.me" ];
            locations."/".proxyPass = "http://192.168.0.6:8123";
          };

          "pve.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "pve.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.21:8006";
          };

          "saw.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "saw.codgician.me" ];
            locations."/" = {
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
            locations."/".root = import ./lumine-web.nix { inherit pkgs; };
          };
        };
      };
    };
  };
}
