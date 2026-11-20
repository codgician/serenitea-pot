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
  port = 3002;
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Calibre Web";
    package = lib.mkPackageOption pkgs "calibre-web" { };

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
          ip = "127.0.0.1";
          inherit port;
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

      codgician.services.nginx.reverseProxies.calibre-web.proxyPass = "http://127.0.0.1:${toString port}";
    })
  ];
}
