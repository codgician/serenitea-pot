{ config, lib, ... }:
let
  cfg = config.codgician.services.nats;
  websocketPort = 9222;
in
{
  options.codgician.services.nats = {
    enable = lib.mkEnableOption "authenticated NATS terminal relay";

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
          # LAN-only transport; application payloads remain end-to-end encrypted.
          no_tls = true;
        };
        # Only public NKeys are deployed; the operator holds the SOPS-encrypted seeds.
        authorization.users = [
          {
            nkey = "UDK3IPDRNO5YXNPDH6YABDAFC6CNXI7NZAVITJKY3VYJY2ZER2DM4WDZ";
            permissions = {
              publish.allow = [ "terminal.codgi.command.>" ];
              subscribe.allow = [ "terminal.codgi.event.>" ];
            };
          }
          {
            nkey = "UAN4DFNR7KAZ5IFDNIOC47S2MHXQC6VLLBY4ZCRGCILMPCIQUQHB2NH4";
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
