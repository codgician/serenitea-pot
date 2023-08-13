{ config, pkgs, lib, ... }:
let
  domain = "amt.codgician.me";
  user = "meshCommander";
  group = "meshCommander";
  port = 3001;
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
      ExecStart = "${pkgs.nodejs}/bin/node --tls-min-v1.1 ${pkgs.nodePackages.meshcommander}/bin/meshcommander --port ${builtins.toString port}";
      ExecStop = "${pkgs.killall}/bin/killall meshcommander";
      Restart = "always";
      User = user;
      Group = group;
    };
  };

  # User and group
  users = {
    users = lib.mkIf (user == "meshCommander") {
      meshCommander = {
        inherit group;
        isSystemUser = true;
      };
    };
    groups = lib.mkIf (group == "meshCommander") {
      meshCommander = { };
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
      proxyWebsockets = true;
      recommendedProxySettings = false;
    };

    forceSSL = true;
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
