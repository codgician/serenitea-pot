{ config, lib, ... }:
let
  serviceName = "callibre-web";
  cfg = config.codgician.services.calibre-web;
  types = lib.types;
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Calibre Web.";

    ip = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        IP for Calibre Web to listen on (use IPv4).
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3002;
      description = ''
        Port for Calibre Web to listen on.
      '';
    };

    calibreLibrary = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to Calibre library.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.ip}:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.calibre-web; http://$\{ip}:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    # Calibre-web settings
    (lib.mkIf cfg.enable {
      services.calibre-web = {
        enable = true;
        listen = {
          port = cfg.port;
          ip = cfg.ip;
        };
        options = {
          enableKepubify = true;
          enableBookConversion = true;
          calibreLibrary = cfg.calibreLibrary;
        };
      };

      # Persist data
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/calibre-web";
        }
      ];
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
