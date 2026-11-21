{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.prometheus;
  defaultDataDir = "/var/lib/prometheus2";

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
    package = lib.mkPackageOption pkgs "prometheus" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = defaultDataDir;
      description = "Path where Prometheus stores its metrics data.";
    };

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
      inherit (cfg) package;
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

    # BindPaths for custom data directory
    systemd.services.prometheus.serviceConfig.BindPaths = lib.mkIf (cfg.dataDir != defaultDataDir) [
      "${cfg.dataDir}:${defaultDataDir}"
    ];

    # Persist data directory (only when using default location)
    codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
      {
        type = "directory";
        path = cfg.dataDir;
      }
    ];
  };
}
