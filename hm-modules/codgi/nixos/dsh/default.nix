{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.dsh;
  svc = osConfig.codgician.inventory.services.dsh-web;

  # The headless service has no XDG Documents directory to discover.
  webPatch = (pkgs.formats.yaml { }).generate "dsh-web.patch.yml" [
    {
      id = "workspace-controller";
      config.documentsDirectory = "${config.home.homeDirectory}/Documents";
    }
  ];
in
{
  # The Web UI runs on the host the inventory places `dsh-web` on.
  config = lib.mkIf (cfg.enable && svc.host == osConfig.networking.hostName) {
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
          (toString svc.port)
          "--no-open"
          "--public-url"
          "https://${svc.domain}/"
          "--trusted-host"
          svc.domain
        ];
        WorkingDirectory = "%h";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
