{ config, lib, ... }:
let
  cfg = config.codgician.services.nats;
  websocketPort = 9222;
in
{
  options.codgician.services.nats = {
    enable = lib.mkEnableOption "authenticated NATS terminal relay";

    openFirewall = lib.mkEnableOption "opening firewall for the NATS WebSocket listener";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address for the authenticated plaintext WebSocket listener.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nats = {
      enable = true;
      serverName = config.networking.hostName;
      jetstream = false;
      settings = {
        # Upstream emits an empty block when disabled; NATS treats that as enabled.
        jetstream = lib.mkForce false;
        host = "127.0.0.1";
        websocket = {
          host = cfg.host;
          port = websocketPort;
          # Application payloads remain end-to-end encrypted over plaintext WebSocket.
          no_tls = true;
        };
        # Only public NKeys are deployed; the operator holds the SOPS-encrypted seeds.
        authorization.users = [
          {
            nkey = "UC25ZHG7YKMOHFNNVQ3QV3XT2GIRMWO5YR5R7R4VU53GTIX5OXHU4TEG";
            permissions = {
              publish.allow = [ "terminal.codgi.command.>" ];
              subscribe.allow = [ "terminal.codgi.event.>" ];
            };
          }
          {
            nkey = "UDL4A3POPXBGYAOVRZVK7JG7OBWYSHWBOXNWAQECDIJPZVTQTP4N5IFE";
            permissions = {
              publish.allow = [ "terminal.codgi.event.>" ];
              subscribe.allow = [ "terminal.codgi.command.>" ];
            };
          }
        ];
        # Do not record command payloads. Core NATS is live delivery, not a replay queue.
        debug = false;
        trace = false;
        trace_verbose = false;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ websocketPort ];

    systemd.services.nats = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    # Upstream creates this directory with StateDirectory; preserve it across root wipes.
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/nats";
        user = "nats";
        group = "nats";
      }
    ];
  };
}
