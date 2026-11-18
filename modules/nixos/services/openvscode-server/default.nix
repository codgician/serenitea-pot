{
  config,
  lib,
  ...
}:
let
  serviceName = "openvscode-server";
  cfg = config.codgician.services.${serviceName};
  inherit (lib.codgician) published;
  svc = published.services.openvscode-server;
in
{
  options.codgician.services.${serviceName}.enable =
    lib.codgician.mkPublishedEnableOption config serviceName;

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.openvscode-server.proxyPass = svc.localUpstream;

      services.openvscode-server = {
        enable = true;
        host = "127.0.0.1";
        inherit (svc) port;
        user = "codgi";
        group = "users";
        withoutConnectionToken = true;
        telemetryLevel = "off";
      };

      assertions = [
        {
          assertion = svc.authelia != null;
          message = "openvscode-server runs without a connection token: put it behind Authelia in the inventory.";
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
