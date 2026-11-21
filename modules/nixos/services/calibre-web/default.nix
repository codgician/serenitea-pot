{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.calibre-web;
  types = lib.types;
  domain = "books.${lib.codgician.zone}";
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Calibre Web";
    package = lib.mkPackageOption pkgs "calibre-web" { };

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
  };

  config = lib.mkMerge [
    { codgician.services.nginx.reverseProxies.calibre-web.domains = [ domain ]; }

    (lib.mkIf cfg.enable {
      services.calibre-web = {
        enable = true;
        inherit (cfg) package;
        listen = {
          inherit (cfg) ip port;
        };
        options = {
          enableKepubify = true;
          enableBookConversion = true;
          inherit (cfg) calibreLibrary;
        };
      };

      # Persist data
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/calibre-web";
        }
      ];

      codgician.services.nginx.reverseProxies.calibre-web.proxyPass =
        "http://${cfg.ip}:${toString cfg.port}";
    })
  ];
}
