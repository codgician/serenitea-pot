{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.opencode;
  inherit (lib) types;
in
{
  options.codgician.codgi.opencode = {
    web = {
      enable = lib.mkEnableOption "opencode web interface";

      hostname = lib.mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Hostname for opencode web interface to listen on.";
      };

      port = lib.mkOption {
        type = types.port;
        default = 3030;
        description = "Port for opencode web interface to listen on.";
      };

      enableMdns = lib.mkEnableOption "mDNS for local network discovery";
    };
  };

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
            (lib.getExe cfg.package)
            "web"
            "--hostname"
            cfg.web.hostname
            "--port"
            (toString cfg.web.port)
          ]
          ++ lib.optionals cfg.web.enableMdns [ "--mdns" ]
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
