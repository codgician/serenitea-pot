{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
  relayDomain = lib.codgician.published.services.ovis-relay.domain;
in
{
  options.codgician.codgi.herdr.ovis.enable =
    lib.mkEnableOption "Ovis browser and phone client for Herdr";

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Inherit the user manager environment, including the complete NixOS PATH.
      systemd.user.services.herdr = {
        Unit = {
          Description = "Herdr terminal workspace server";
          X-Restart-Triggers = [ config.xdg.configFile."herdr/config.toml".source ];
        };

        Service = {
          ExecStart = "${lib.getExe pkgs.llm-agents.herdr} server";
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
          ExecStart = lib.getExe pkgs.llm-agents.ovis;
          Environment = [
            "HOST=127.0.0.1"
            "PORT=7317"
            # A second listener on private LAN addresses; it admits only
            # paired devices or the token.
            "OVIS_LAN_HTTPS_PORT=7318"
          ]
          ++ lib.optional cfg.desktop.enable "OVIS_HC_BIN=${lib.getExe pkgs.llm-agents.herdr-core}"
          # The self-hosted relay and app instead of app.ovis.sh
          ++ [
            "OVIS_RELAY_URL=wss://${relayDomain}"
            "OVIS_RELAY_APP_URL=https://${relayDomain}"
          ];
          Restart = "on-failure";
          RestartSec = "5s";
        };

        Install.WantedBy = [ "default.target" ];
      };
    })
  ];
}
