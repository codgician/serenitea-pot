{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "meshcentral";
  cfg = config.codgician.services.meshcentral;
  types = lib.types;
in
{
  options.codgician.services.meshcentral = {
    enable = lib.mkEnableOption "meshcentral";

    package = lib.mkPackageOption pkgs "meshcentral" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for meshcentral to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3001;
      description = "TCP port for meshcentral to listen.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.meshcentral; http://$\{host}:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    # Meshcentral configurations
    (lib.mkIf cfg.enable {
      services.meshcentral = {
        enable = true;
        settings = {
          domains."".allowedOrigin = lib.mkIf cfg.reverseProxy.enable cfg.reverseProxy.domains;
          settings = {
            PortBind = cfg.host;
            Port = cfg.port;
            TlsOffload = "127.0.0.1,::1";
          };
        };
      };
    })

    # Reverse proxy profiles
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
      overrideVhostConfig.locations."/" = {
        inherit (cfg.reverseProxy) lanOnly;
        authelia.enable = cfg.reverseProxy.authelia.enable;
        passthru = {
          inherit (cfg.reverseProxy) proxyPass;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    })
  ];
}
