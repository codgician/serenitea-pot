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

    scrapeConfigs = {
      prometheus = lib.mkEnableOption "Prometheus self-scrape";

      nginx = lib.mkEnableOption "Nginx exporter scrape (stub_status)";

      nginxlog = lib.mkEnableOption "Nginxlog exporter scrape (access logs)";

      extraConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Scrape configurations added after those of Prometheus itself and of nginx.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1"; # Security: bind to localhost only
      scrapeConfigs =
        lib.optional cfg.scrapeConfigs.prometheus (
          mkLocalScrape "prometheus" config.services.prometheus.port
        )
        ++ lib.optional cfg.scrapeConfigs.nginx (
          mkLocalScrape "nginx" config.services.prometheus.exporters.nginx.port
        )
        ++ lib.optional cfg.scrapeConfigs.nginxlog (
          mkLocalScrape "nginxlog" config.services.prometheus.exporters.nginxlog.port
        )
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
