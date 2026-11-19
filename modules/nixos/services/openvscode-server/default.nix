{
  config,
  lib,
  ...
}:
let
  serviceName = "openvscode-server";
  cfg = config.codgician.services.${serviceName};
  port = 3000;
in
{
  options.codgician.services.${serviceName}.enable = lib.mkEnableOption "OpenVSCode Server";

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.openvscode-server.proxyPass =
        "http://127.0.0.1:${toString port}";

      services.openvscode-server = {
        enable = true;
        host = "127.0.0.1";
        inherit port;
        user = "codgi";
        group = "users";
        withoutConnectionToken = true;
        telemetryLevel = "off";
      };
    })

    {
      codgician.services.nginx.reverseProxies.openvscode-server = {
        domains = [ "leyline.${lib.codgician.zone}" ];
        # The server runs without a connection token.
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
