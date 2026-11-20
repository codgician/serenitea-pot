{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.jellyfin;
  domain = "fin.${lib.codgician.zone}";
  defaultDataDir = "/var/lib/jellyfin";
in
{
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin";
    package = lib.mkPackageOption pkgs "jellyfin" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = defaultDataDir;
      description = "Data directory for jellyfin";
    };
  };

  config = lib.mkMerge [
    { codgician.services.nginx.reverseProxies.jellyfin.domains = [ domain ]; }

    (lib.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
        inherit (cfg) package dataDir;
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

      codgician.services.nginx.reverseProxies.jellyfin.proxyPass = "http://127.0.0.1:8096";
    })
  ];
}
