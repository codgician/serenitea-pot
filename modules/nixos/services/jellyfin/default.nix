{ config, lib, ... }:
let
  serviceName = "jellyfin";
  cfg = config.codgician.services.jellyfin;
  systemCfg = config.codgician.system;
  types = lib.types;
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

      # Persist data when dataDir is default value
      environment = lib.optionalAttrs (systemCfg ? impermanence) {
        persistence.${systemCfg.impermanence.path}.directories =
          lib.mkIf (cfg.dataDir == options.codgician.services.jellyfin.dataDir.default)
            [
              {
                directory = cfg.dataDir;
                mode = "0750";
                inherit (cfg) user group;
              }
            ];
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
