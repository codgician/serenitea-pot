{ config, lib, ... }:
let
  cfg = config.codgician.services.jellyfin;
  svc = config.codgician.inventory.services.jellyfin;
  defaultDataDir = "/var/lib/jellyfin";
in
{
  options.codgician.services.jellyfin = {
    enable = lib.codgician.mkPublishedEnableOption config "jellyfin";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = defaultDataDir;
      description = "Data directory for jellyfin";
    };
  };

  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
      inherit (cfg) dataDir;
    };

    # Ensure data directory exists (for custom paths)
    systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != defaultDataDir) [
      "d ${cfg.dataDir} 0700 jellyfin jellyfin -"
    ];

    # Persist default data directory
    codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
      {
        type = "directory";
        path = cfg.dataDir;
        user = "jellyfin";
        group = "jellyfin";
      }
    ];

    codgician.services.nginx.reverseProxies.jellyfin.proxyPass = svc.localUpstream;
  };
}
