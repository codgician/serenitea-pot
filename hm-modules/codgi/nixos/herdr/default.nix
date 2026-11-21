{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
  inherit (lib) types;
in
{
  options.codgician.codgi.herdr.ovis = {
    enable = lib.mkEnableOption "Ovis browser and phone client for Herdr";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llm-agents.ovis.override { herdr = cfg.package; };
      defaultText = lib.literalExpression ''
        pkgs.llm-agents.ovis.override { herdr = config.codgician.codgi.herdr.package; }
      '';
      description = "The Ovis package to run.";
    };

    hostname = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Hostname for the Ovis HTTP and WebSocket server to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 7317;
      description = "Port for the Ovis HTTP and WebSocket server to listen on.";
    };

    lanHttpsPort = lib.mkOption {
      type = types.nullOr types.port;
      default = null;
      example = 7318;
      description = ''
        Port for the additional Ovis HTTPS listener on private LAN addresses.
        It admits only paired devices or the token, even before the first pairing.
        When null, the listener is disabled.
      '';
    };

    relayDomain = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "euthymia.${lib.codgician.zone}";
      description = ''
        Domain serving a self-hosted Ovis relay and app (see `codgician.services.ovis-relay`).
        When set, Ovis uses only this relay, and its pairing links open this app instead of app.ovis.sh.
        When null, Ovis uses its public relay.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Inherit the user manager environment, including the complete NixOS PATH.
      systemd.user.services.herdr = {
        Unit = {
          Description = "Herdr terminal workspace server";
          X-Restart-Triggers = [ config.xdg.configFile."herdr/config.toml".source ];
        };

        Service = {
          ExecStart = "${lib.getExe cfg.package} server";
          Restart = "on-failure";
          RestartSec = "2s";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })

    (lib.mkIf cfg.ovis.enable {
      assertions = [
        {
          assertion = cfg.enable || cfg.desktop.enable;
          message = "codgician.codgi.herdr.ovis requires the Herdr TUI or desktop stack to be enabled.";
        }
      ];

      systemd.user.services.ovis = {
        Unit = {
          Description = "Ovis browser and phone client for Herdr";
          After = lib.optionals cfg.enable [ "herdr.service" ];
        };

        Service = {
          ExecStart = lib.getExe cfg.ovis.package;
          Environment = [
            "HOST=${cfg.ovis.hostname}"
            "PORT=${toString cfg.ovis.port}"
          ]
          ++ lib.optional (
            cfg.ovis.lanHttpsPort != null
          ) "OVIS_LAN_HTTPS_PORT=${toString cfg.ovis.lanHttpsPort}"
          ++ lib.optional cfg.desktop.enable "OVIS_HC_BIN=${lib.getExe cfg.desktop.corePackage}"
          ++ lib.optionals (cfg.ovis.relayDomain != null) [
            "OVIS_RELAY_URL=wss://${cfg.ovis.relayDomain}"
            "OVIS_RELAY_APP_URL=https://${cfg.ovis.relayDomain}"
          ];
          Restart = "on-failure";
          RestartSec = "5s";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
