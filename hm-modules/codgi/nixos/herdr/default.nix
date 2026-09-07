{
  config,
  lib,
  ...
}:
let
  cfg = config.codgician.codgi.herdr;
in
{
  config = lib.mkIf cfg.enable {
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
  };
}
