{ config, lib, ... }:
let
  cfg = config.codgician.services.calibre-web;
  systemCfg = config.codgician.system;
  types = lib.types;
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Enable Calibre Web.";

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
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for Calibre Web.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://${cfg.ip}:${toString cfg.port}";
        defaultText = ''http://$\{config.codgician.services.calibre-web.ip}:$\{toString config.codgician.services.calibre-web.port}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
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
      environment = lib.optionalAttrs (systemCfg ? impermanence) {
        persistence.${systemCfg.impermanence.path}.directories = [ "/var/lib/calibre-web" ];
      };
    })

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.calibre-web = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };
    })
  ];
}
