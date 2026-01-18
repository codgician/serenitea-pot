{ pkgs, ... }:
{
  codgician.services = {
    # Global Anubis configuration
    anubis = {
      enable = true;
      cookieDomain = "codgician.me";
      defaultDifficulty = 4;
      defaultOgPassthrough = true;
    };

    authelia.instances.main = {
      domain = "auth.codgician.me";
      reverseProxy = {
        enable = true;
        proxyPass = "https://192.168.0.22";
        anubis.enable = true; # Phase 1: Protected
      };
    };

    openvscode-server.reverseProxy = {
      enable = true;
      domains = [ "leyline.codgician.me" ];
      proxyPass = "https://192.168.0.8";
    };

    comfyui.reverseProxy = {
      enable = true;
      domains = [ "vanarana.codgician.me" ];
      proxyPass = "https://192.168.0.22";
    };

    dendrite = {
      domain = "matrix.codgician.me";
      reverseProxy = {
        enable = true;
        elementWeb = true;
        proxyPass = "https://192.168.0.22";
      };
    };

    docling-serve.reverseProxy = {
      enable = true;
      domains = [ "vision.codgician.me" ];
      proxyPass = "https://192.168.0.22";
    };

    fish-speech.gradio.reverseProxy = {
      enable = true;
      domains = [ "voice.codgician.me" ];
      proxyPass = "https://192.168.0.22";
    };

    gitlab = {
      host = "git.codgician.me";
      reverseProxy = {
        enable = true;
        proxyPass = "https://192.168.0.22";
        anubis.enable = true; # Phase 1: Protected
      };
    };

    grafana.reverseProxy = {
      enable = true;
      domains = [ "lumenstone.codgician.me" ];
      proxyPass = "http://192.168.0.22";
      anubis.enable = true; # Phase 1: Protected
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

    nginx = {
      enable = true;
      openFirewall = true;
      reverseProxies = {
        "fragments.codgician.me" = {
          enable = true;
          domains = [ "fragments.codgician.me" ];
          locations."/".passthru.proxyPass = "https://192.168.0.8";
        };

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
          authelia = {
            enable = true;
            rules = [
              {
                groups = [ "saw" ];
                policy = "two_factor";
              }
            ];
          };
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
          # Note: Anubis not enabled for static sites (no backend to protect)
          locations."/".passthru.root = import ./lumine-web.nix { inherit pkgs; };
        };
      };
    };
  };
}
