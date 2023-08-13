{ config, pkgs, ... }:
let
  domain = "amt.codgician.me";
  port = 3000;
in
{
  # Systemd service for mesh commander
  systemd.services.meshCommander = {
    enable = true;
    restartIfChanged = true;
    description = "Mesh Commander Server for Intel AMT Management";
    wantedBy = [ "default.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nodejs}/bin/node ${pkgs.nodePackages.meshcommander}/bin/meshcommander --port ${builtins.toString port}";
      ExecStop = "${pkgs.killall}/bin/killall meshcommander";
      Restart = "always";
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/".proxyPass = "http://localhost:${builtins.toString port}";
    forceSSL = true;
    http2 = true;
    enableACME = true;
    acmeRoot = null;
  };

  # SSL certificate
  security.acme.certs."${domain}" = {
    inherit domain;
    extraDomainNames = [
      "sz.codgician.me"
      "sz4.codgician.me"
      "sz6.codgician.me"
    ];
    group = config.services.nginx.user;
  };
}
