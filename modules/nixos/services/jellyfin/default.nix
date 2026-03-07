{ config, lib, ... }:
let
  serviceName = "jellyfin";
  cfg = config.codgician.services.jellyfin;
  types = lib.types;
  defaultDataDir = "/var/lib/jellyfin";
in
rec {
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin";

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
      default = "/var/lib/jellyfin";
      description = "Data directory for jellyfin";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:8096";
    };
  };

  config = lib.mkMerge [
    # Jellyfin configurations
    (lib.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
        inherit (cfg)
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
    })

    # Reverse proxy profile
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      };
    }
  ];
}
