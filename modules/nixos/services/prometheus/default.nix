{
  config,
  lib,
  ...
}:
let
  serviceName = "prometheus";
  cfg = config.codgician.services.${serviceName};
  defaultDataDir = "/var/lib/prometheus2";
  # Default scrape configs when self-monitoring is enabled
  # Use explicit 127.0.0.1 to match listenAddress binding (avoids IPv6 resolution issues)
  defaultScrapeConfigs = lib.optionals cfg.scrapeConfigs.prometheus [
    {
      job_name = "prometheus";
      static_configs = [
        {
          targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
          labels = {
            instance = config.networking.hostName;
          };
        }
      ];
    }
  ];

  # Nginx exporter scrape config
  nginxScrapeConfigs = lib.optionals cfg.scrapeConfigs.nginx [
    {
      job_name = "nginx";
      static_configs = [
        {
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}"
          ];
          labels = {
            instance = config.networking.hostName;
          };
        }
      ];
    }
  ];

  # Nginxlog exporter scrape config
  nginxlogScrapeConfigs = lib.optionals cfg.scrapeConfigs.nginxlog [
    {
      job_name = "nginxlog";
      static_configs = [
        {
          targets = [
            "127.0.0.1:${toString config.services.prometheus.exporters.nginxlog.port}"
          ];
          labels = {
            instance = config.networking.hostName;
          };
        }
      ];
    }
  ];
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "prometheus";

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
        description = "Additional scrape configurations to add.";
        example = lib.literalExpression ''
          [
            {
              job_name = "node";
              static_configs = [{ targets = [ "localhost:9100" ]; }];
            }
          ]
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1"; # Security: bind to localhost only
      scrapeConfigs =
        defaultScrapeConfigs
        ++ nginxScrapeConfigs
        ++ nginxlogScrapeConfigs
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
