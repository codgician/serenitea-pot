{
  config,
  lib,
  ...
}:
let
  serviceName = "openvscode-server";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
  inherit (lib.codgician) published;
  svc = published.services.openvscode-server;
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.codgician.mkPublishedEnableOption config serviceName;

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
      codgician.services.nginx.reverseProxies.openvscode-server.proxyPass = svc.localUpstream;

      services.openvscode-server = {
        enable = true;
        host = "127.0.0.1";
        inherit (svc) port;
        inherit (cfg)
          user
          group
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
              user = cfg.user;
              group = cfg.group;
            }
            ++ lib.optional (cfg.userDataDir != null && cfg.userDataDir != cfg.serverDataDir) {
              type = "directory";
              path = cfg.userDataDir;
              user = cfg.user;
              group = cfg.group;
            }
            ++ lib.optional (cfg.extensionsDir != null && cfg.extensionsDir != cfg.serverDataDir) {
              type = "directory";
              path = cfg.extensionsDir;
              user = cfg.user;
              group = cfg.group;
            }
          );

      # Ensure authentication is configured
      assertions = [
        {
          assertion = cfg.connectionTokenFile != null || svc.authelia != null;
          message = ''
            openvscode-server: Authentication is required.

            Either:
            1. Put it behind Authelia in the inventory (recommended)
            2. Provide a connection token: connectionTokenFile = "/path/to/token"
          '';
        }
      ];
    })

    # Long timeouts for WebSocket
    (lib.mkIf (cfg.enable || published.fronts config.networking.hostName serviceName) {
      codgician.services.nginx.reverseProxies.openvscode-server.locations."/".extraConfig = ''
        # Long timeouts for IDE (terminals, LSPs can idle)
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;

        # Disable buffering for real-time IDE updates
        proxy_buffering off;
      '';
    })
  ];
}
