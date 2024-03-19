{ config, lib, pkgs, ... }:
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

    reverseProxy = {
      enable = lib.mkEnableOption "Enable nginx reverse proxy profile for jellyfin.";

      https = lib.mkEnableOption "Use https and auto-renew certificates.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        default = [ "fin.codgician.me" ];
        description = lib.mdDoc "List of domains. The first one will be treated as virtual host name.";
      };
    };
  };

  config =
    let
      virtualHost =
        if cfg.reverseProxy.domains == [ ]
        then null
        else builtins.head cfg.reverseProxy.domains;
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

      # Reverse proxy
      {
        services.nginx.virtualHosts."${virtualHost}" = {
          locations."/" = {
            proxyPass = "http://localhost:8096";
            proxyWebsockets = true;
          };

          # Don't include me in search results
          locations."/robots.txt".return = "200 'User-agent:*\\nDisallow:*'";

          forceSSL = cfg.reverseProxy.https;
          http2 = true;
          enableACME = cfg.reverseProxy.https;
          acmeRoot = null;
        };

        # SSL certificate
        codgician.acme = lib.mkIf cfg.reverseProxy.https {
          "${virtualHost}" = {
            enable = true;
            extraDomainNames = builtins.tail cfg.reverseProxy.domains;
          };
        };
      }

      # Assertions
      {
        assertions = [
          {
            assertion = !cfg.enable || !cfg.reverseProxy.enable || builtins.length cfg.reverseProxy.domains > 0;
            message = ''You have to provide at least one domain if `jellyfin.reverseProxy` is enabled.'';
          }
        ];
      }
    ]);
}
