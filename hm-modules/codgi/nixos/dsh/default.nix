{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dsh;
  inherit (lib) types;

  # The headless service has no XDG Documents directory to discover.
  webPatch = (pkgs.formats.yaml { }).generate "dsh-web.patch.yml" [
    {
      id = "workspace-controller";
      config.documentsDirectory = "${config.home.homeDirectory}/Documents";
    }
  ];
in
{
  options.codgician.codgi.dsh.web = {
    domain = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "HTTPS domain of the authenticated proxy for the dsh Web UI; null disables it.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 3080;
      description = "Loopback port for the dsh Web UI.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.web.domain != null) {
    systemd.user.services.dsh-web = {
      Unit.Description = "DeepSeek Harness Web UI";
      Service = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe cfg.wrappedPackage)
          "web"
          "--patch"
          (toString webPatch)
          "--host"
          "127.0.0.1"
          "--port"
          (toString cfg.web.port)
          "--no-open"
          "--public-url"
          "https://${cfg.web.domain}/"
          "--trusted-host"
          cfg.web.domain
        ];
        WorkingDirectory = "%h";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
