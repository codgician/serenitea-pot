{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.jellyfin;
  systemCfg = config.codgician.system;
  types = lib.types;
in
{
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Enable Jellyfin.";

    user = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = lib.mdDoc "User under which jellyfin runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = lib.mdDoc "Group under which jellyfin runs.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/jellyfin";
      description = lib.mdDoc "Data directory for jellyfin.";
    };

    reverseProxy = lib.mkOption {
      type = types.submodule (import ../nginx/reverse-proxy-options.nix { inherit config lib; });
      default = {};
    };
  };

  config =
    let
      virtualHost =
        if cfg.reverseProxy.domains == [ ]
        then null else builtins.head cfg.reverseProxy.domains;
    in
    lib.mkIf cfg.enable (lib.mkMerge [
      # Service
      {
        services.jellyfin = {
          enable = true;
          openFirewall = true;
          user = cfg.user;
          group = cfg.group;
        };

        # Persist data
        environment = lib.optionalAttrs (systemCfg?impermanence) {
          persistence.${systemCfg.impermanence.path}.directories =
            lib.mkIf (cfg.dataDir == options.codgician.services.jellyfin.dataDir.default) [ cfg.dataDir ];
        };
      }

      (lib.mkIf cfg.reverseProxy.enable {
        # Reverse proxy
        codgician.services.nginx.enable = true;

        services.nginx.virtualHosts = lib.optionalAttrs virtualHost != null
        {
          "${virtualHost}" = {
            locations."/" = {
              proxyPass = "http://localhost:8096";
              proxyWebsockets = true;
              extraConfig = lib.optionals cfg.reverseProxy.lanOnly ''
                allow 10.0.0.0/8;
                allow 172.16.0.0/12;
                allow 192.168.0.0/16;
                allow fc00::/7;
                deny all;
              '';
            };

            # Don't include me in search results
            locations."/robots.txt".return = "200 'User-agent:*\\nDisallow:*'";

            forceSSL = cfg.reverseProxy.https;
            http2 = true;
            enableACME = cfg.reverseProxy.https;
            acmeRoot = null;
          };
        };

        # SSL certificate
        codgician.acme = lib.optionalAttrs cfg.reverseProxy.https {
          "${virtualHost}" = {
            enable = true;
            extraDomainNames = builtins.tail cfg.reverseProxy.domains;
          };
        };
      })

      # Assertions
      {
        assertions = [
          {
            assertion = !cfg.enable || !cfg.reverseProxy.enable || virtualHost != null;
            message = ''You have to provide at least one domain if `jellyfin.reverseProxy` is enabled.'';
          }
        ];
      }
    ]);
}
