{ config, lib, ... }:
let
  serviceName = "nats";
  cfg = config.codgician.services.nats;
  websocketPort = 9222;
in
{
  options.codgician.services.nats = {
    enable = lib.mkEnableOption "authenticated NATS terminal relay";

    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString websocketPort}";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.reverseProxy.enable || cfg.reverseProxy.https;
          message = "NATS relay requires HTTPS for its public WebSocket endpoint.";
        }
      ];

      services.nats = {
        enable = true;
        serverName = config.networking.hostName;
        jetstream = false;
        settings = {
          # Upstream emits an empty block when disabled; NATS treats that as enabled.
          jetstream = lib.mkForce false;
          host = "127.0.0.1";
          websocket = {
            host = "127.0.0.1";
            port = websocketPort;
            # TLS terminates at the local Nginx proxy, never on a public plaintext listener.
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

      # Upstream creates this directory with StateDirectory; preserve it across root wipes.
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/var/lib/nats";
          user = "nats";
          group = "nats";
        }
      ];
    })

    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
        extraVhostConfig.locations."/".passthru.extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 1h;
          proxy_send_timeout 1h;
        '';
      };
    }
  ];
}
