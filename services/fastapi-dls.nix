{ config, pkgs, lib, ... }:
let
  user = "fastapi-dls";
  group = "fastapi-dls";
  domain = "nvdls.codgician.me";
  port = 14514;
  appDir = "${pkgs.nur.repos.xddxdd.fastapi-dls}/opt/app";
in
{
  # Systemd service for fastapi-dls
  systemd.services.fastapi-dls = {
    enable = true;
    restartIfChanged = true;
    description = "fastapi-dls";
    wantedBy = [ "multi-user.target" ];
    requires = [ "acme-finished-${domain}.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = let
        credsDir = "/run/credentials/fastapi-dls.service";
      in ''
        ${pkgs.nur.repos.xddxdd.fastapi-dls}/bin/fastapi-dls \
          --host ${domain} --port ${builtins.toString port} \
          --app-dir ${appDir} \
          --ssl-keyfile ${credsDir}/key.pem --ssl-certfile ${credsDir}/cert.pem \
          --proxy-headers
      '';
      LoadCredential = let  
        certDir = config.security.acme.certs."${domain}".directory;
      in [
        "cert.pem:${certDir}/cert.pem"
        "key.pem:${certDir}/key.pem"
      ];
      WorkingDirectory = appDir;
      Restart = "always";
      User = user;
      Group = group;
      KillSignal = "SIGQUIT";
    };
  };

  # User and group
  users = {
    users = lib.mkIf (user == "fastapi-dls") {
      fastapi-dls = {
        inherit group;
        isSystemUser = true;
      };
    };
    groups = lib.mkIf (group == "fastapi-dls") {
      fastapi-dls = { };
    };
  };

  # Ngnix configurations
  services.nginx.virtualHosts."${domain}" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        allow 192.168.0.0/16;
        allow fc00::/7;
        deny all;
        proxy_buffering off;
      '';
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

    # Load new certificate
    postRun = ''
      systemctl restart fastapi-dls
    '';
  };
}
