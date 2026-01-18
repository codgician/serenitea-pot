{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;

  # Enable mDNS when hostname is not localhost (service is network-exposed)
  enableMdns = cfg.web.hostname != "127.0.0.1" && cfg.web.hostname != "localhost";
in
{
  config = lib.mkIf (cfg.enable && cfg.web.enable) {
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "opencode web interface";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe config.programs.opencode.package)
            "web"
            "--hostname"
            cfg.web.hostname
            "--port"
            (builtins.toString cfg.web.port)
          ]
          ++ lib.optionals enableMdns [ "--mdns" ]
        );
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
