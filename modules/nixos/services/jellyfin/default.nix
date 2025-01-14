{ config, lib, ... }:
let
  cfg = config.codgician.services.jellyfin;
  systemCfg = config.codgician.system;
  types = lib.types;
in
rec {
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Enable Jellyfin.";

    user = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = "User under which jellyfin runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = "Group under which jellyfin runs.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/jellyfin";
      description = "Data directory for jellyfin.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for Jellyfin.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://127.0.0.1:8096";
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    # Jellyfin configurations
    (lib.mkIf cfg.enable {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
        user = cfg.user;
        group = cfg.group;
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
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.jellyfin = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };
    })
  ];
}
