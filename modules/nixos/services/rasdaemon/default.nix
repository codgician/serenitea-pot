{
  config,
  lib,
  ...
}:
let
  serviceName = "rasdaemon";
  cfg = config.codgician.services.${serviceName};
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "rasdaemon RAS (Reliability, Availability, Serviceability) error logging";

    prometheus = {
      enable = lib.mkEnableOption "Prometheus exporter for rasdaemon RAS events";

      scrapeConfig = lib.mkEnableOption "Prometheus scrape config for the rasdaemon exporter";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Log Machine Check Exceptions, EDAC (memory controller / DIMM) and
        # PCIe AER (SERR) events from kernel tracing, and persist them to
        # /var/lib/rasdaemon/ras-mc_event.db for later inspection via
        # `ras-mc-ctl --errors` / `--summary`.
        hardware.rasdaemon = {
          enable = true;
          record = true;
        };

        # Persist the SQLite event database across boots/wipes.
        codgician.system.impermanence.extraItems = [
          {
            type = "directory";
            path = "/var/lib/rasdaemon";
          }
        ];
      }

      (lib.mkIf cfg.prometheus.enable {
        services.prometheus.exporters.rasdaemon = {
          enable = true;
          # Bind to localhost only; scrape locally or over an already-trusted
          # network boundary (e.g. Prometheus running on the same host).
          listenAddress = "127.0.0.1";
          enabledCollectors = [
            "aer" # PCIe Advanced Error Reporting (e.g. PCI SERR)
            "mce" # CPU Machine Check Exceptions
            "mc" # EDAC Memory Controller / DIMM ECC errors
          ];
        };
      })

      (lib.mkIf cfg.prometheus.scrapeConfig {
        codgician.services.prometheus.scrapeConfigs.extraConfigs = [
          {
            job_name = "rasdaemon";
            static_configs = [
              {
                targets = [
                  "127.0.0.1:${toString config.services.prometheus.exporters.rasdaemon.port}"
                ];
                labels.instance = config.networking.hostName;
              }
            ];
          }
        ];
      })
    ]
  );
}
