{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "openvscode-server";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "OpenVSCode Server";
    package = lib.mkPackageOption pkgs "openvscode-server" { };

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "The user to run openvscode-server as.";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "The group to run openvscode-server as.";
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for openvscode-server to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 3000;
      description = "Port for openvscode-server to listen on.";
    };

    serverDataDir = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Directory for server data.";
    };

    userDataDir = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Directory for user data (settings, etc).";
    };

    extensionsDir = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Directory for extensions.";
    };

    connectionTokenFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/openvscode-token";
      description = ''
        Path to file containing the connection token.
        When set, connection token authentication is enabled.
        When null, the server runs without connection token
        (ensure access is protected by other means like Authelia).
      '';
    };

    extraArguments = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--log=debug" ];
      description = "Additional arguments to pass to openvscode-server.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.openvscode-server.proxyPass =
        "http://${cfg.host}:${toString cfg.port}";

      services.openvscode-server = {
        enable = true;
        inherit (cfg)
          package
          user
          group
          host
          port
          serverDataDir
          userDataDir
          extensionsDir
          connectionTokenFile
          extraArguments
          ;

        # Enable token-less mode only when no token file is provided
        withoutConnectionToken = cfg.connectionTokenFile == null;

        telemetryLevel = "off";
      };

      # Persist data directories if using impermanence
      codgician.system.impermanence.extraItems =
        lib.optionals config.codgician.system.impermanence.enable
          (
            lib.optional (cfg.serverDataDir != null) {
              type = "directory";
              path = cfg.serverDataDir;
              inherit (cfg) user group;
            }
            ++ lib.optional (cfg.userDataDir != null && cfg.userDataDir != cfg.serverDataDir) {
              type = "directory";
              path = cfg.userDataDir;
              inherit (cfg) user group;
            }
            ++ lib.optional (cfg.extensionsDir != null && cfg.extensionsDir != cfg.serverDataDir) {
              type = "directory";
              path = cfg.extensionsDir;
              inherit (cfg) user group;
            }
          );

      # Ensure authentication is configured
      assertions = [
        {
          assertion =
            cfg.connectionTokenFile != null
            || config.codgician.services.nginx.reverseProxies.openvscode-server.authelia != null;
          message = ''
            openvscode-server: Authentication is required.

            Either:
            1. Keep Authelia on the site: codgician.services.nginx.reverseProxies.openvscode-server.authelia (recommended)
            2. Provide a connection token: connectionTokenFile = "/path/to/token"
          '';
        }
      ];
    })

    {
      codgician.services.nginx.reverseProxies.openvscode-server = {
        domains = [ "leyline.${lib.codgician.zone}" ];
        # Without connectionTokenFile the server has no authentication of its own.
        authelia.users = [ "leyline" ];
        locations."/".extraConfig = ''
          # Long timeouts for IDE (terminals, LSPs can idle)
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          send_timeout 3600s;

          # Disable buffering for real-time IDE updates
          proxy_buffering off;
        '';
      };
    }
  ];
}
