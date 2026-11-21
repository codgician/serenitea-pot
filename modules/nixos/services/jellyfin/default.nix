{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "jellyfin";
  cfg = config.codgician.services.jellyfin;
  types = lib.types;
  domain = "fin.${lib.codgician.zone}";
  defaultDataDir = "/var/lib/jellyfin";
in
{
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin";
    package = lib.mkPackageOption pkgs "jellyfin" { };

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "User under which jellyfin runs";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which jellyfin runs";
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = "/var/cache/jellyfin";
      description = "Cache directory for jellyfin";
    };

    dataDir = lib.mkOption {
      type = types.path;
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
        inherit (cfg)
          package
          user
          group
          cacheDir
          dataDir
          ;
      };

      # Ensure data directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != defaultDataDir) [
        "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group} -"
      ];

      # Persist default data directory
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
        {
          type = "directory";
          path = cfg.dataDir;
          inherit (cfg) user group;
        }
      ];

      codgician.services.nginx.reverseProxies.jellyfin.proxyPass = "http://127.0.0.1:8096";
    })
  ];
}
