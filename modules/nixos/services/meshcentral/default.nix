{
  config,
  lib,
  pkgs,
  ...
}:
let
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
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for meshcentral.";

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
        default = "http://127.0.0.1:${toString cfg.port}";
        defaultText = ''http://127.0.0.1:$\{toString config.codgician.services.meshcentral.port}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
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
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.meshcentral = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      };
    })
  ];
}
