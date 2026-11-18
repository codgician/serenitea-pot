{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.services.rasdaemon;
in
{
  options.codgician.services.rasdaemon.enable =
    lib.mkEnableOption "rasdaemon RAS (Reliability, Availability, Serviceability) error logging";

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

      # Export the events where a Prometheus runs to scrape them.
      (lib.mkIf config.codgician.services.prometheus.enable {
        services.prometheus.exporters.rasdaemon = {
          enable = true;
          listenAddress = "127.0.0.1";
          enabledCollectors = [
            "aer" # PCIe Advanced Error Reporting (e.g. PCI SERR)
            "mce" # CPU Machine Check Exceptions
            "mc" # EDAC Memory Controller / DIMM ECC errors
          ];
        };

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
