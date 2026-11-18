{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.services.prometheus;

  # Explicit 127.0.0.1 matches the listen addresses (avoids IPv6 resolution issues)
  mkLocalScrape = job_name: port: {
    inherit job_name;
    static_configs = [
      {
        targets = [ "127.0.0.1:${toString port}" ];
        labels = {
          instance = config.networking.hostName;
        };
      }
    ];
  };
in
{
  options.codgician.services.prometheus = {
    enable = lib.mkEnableOption "prometheus";

    scrapeConfigs.extraConfigs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Scrape configurations added after those of Prometheus itself and of nginx.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1"; # Security: bind to localhost only
      scrapeConfigs = [
        (mkLocalScrape "prometheus" config.services.prometheus.port)
        (mkLocalScrape "nginx" config.services.prometheus.exporters.nginx.port)
        (mkLocalScrape "nginxlog" config.services.prometheus.exporters.nginxlog.port)
      ]
      ++ cfg.scrapeConfigs.extraConfigs;
    };

    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/prometheus2";
      }
    ];
  };
}
