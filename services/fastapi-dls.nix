{ config, pkgs, lib, ... }:
let
  user = "fastapi-dls";
  group = "fastapi-dls";
  domain = "nvdls.codgician.me";
  leaseDays = 90;
  port = 14514;
  dataDir = "/mnt/data/fastapi-dls";
  appDir = "/var/lib/fastapi-dls-app";
in
{
  # Create working directory if not exist
  system.activationScripts.makeFastApiDlsAppDir =
    let
      sourceDir = "${pkgs.nur.repos.xddxdd.fastapi-dls}/opt/app";
    in
    lib.stringAfter [ "var" ] ''
      # Link python scripts
      if [ ! -d "${appDir}" ]; then
        mkdir -p ${appDir}/cert
      fi
      rm -rf ${appDir}/main.py
      ln -s ${sourceDir}/main.py ${appDir}/main.py
      rm -rf ${appDir}/orm.py     
      ln -s ${sourceDir}/orm.py ${appDir}/orm.py
      rm -rf ${appDir}/util.py
      ln -s ${sourceDir}/util.py ${appDir}/util.py

      # Create JWT token
      if [ ! -d "${dataDir}/cert" ]; then
        mkdir -p ${dataDir}/cert
      fi
      if [ ! -f "${dataDir}/cert/instance.private.pem" ]; then 
        ${pkgs.openssl}/bin/openssl genrsa -out ${dataDir}/cert/instance.private.pem 2048
      fi
      if [ ! -f "${dataDir}/cert/instance.public.pem" ]; then
        ${pkgs.openssl}/bin/openssl rsa -in ${dataDir}/cert/instance.private.pem -outform PEM -pubout -out ${dataDir}/cert/instance.public.pem
      fi
      rm -rf ${appDir}/cert
      ln -s ${dataDir}/cert ${appDir}/cert

      # Fix up permission
      chmod -R 770 ${appDir}
      chmod -R 770 ${dataDir}      
      chown -R ${user}:${group} ${appDir}
      chown -R ${user}:${group} ${dataDir}
    '';

  # Systemd service for fastapi-dls
  systemd.services.fastapi-dls = {
    enable = true;
    restartIfChanged = true;
    description = "fastapi-dls";
    wantedBy = [ "multi-user.target" ];
    requires = [ "acme-finished-${domain}.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart =
        let
          credsDir = "/run/credentials/fastapi-dls.service";
          envFile = pkgs.writeTextFile {
            name = "fastapi-dls-env";
            text = ''
              DLS_URL=${domain}
              DLS_PORT=443
              LEASE_EXPIRE_DAYS=${builtins.toString leaseDays}
              DATABASE=sqlite:///${dataDir}/db.sqlite
            '';
          };
        in
        ''
          ${pkgs.nur.repos.xddxdd.fastapi-dls}/bin/fastapi-dls \
            --host 127.0.0.1 --port ${builtins.toString port} \
            --app-dir ${appDir} \
            --ssl-keyfile ${credsDir}/key.pem --ssl-certfile ${credsDir}/cert.pem \
            --env-file ${envFile} \
            --proxy-headers
        '';
      LoadCredential =
        let
          certDir = config.security.acme.certs."${domain}".directory;
        in
        [
          "cert.pem:${certDir}/cert.pem"
          "key.pem:${certDir}/key.pem"
        ];
      WorkingDirectory = appDir;
      Restart = "always";
      User = user;
      Group = group;
      KillSignal = "SIGQUIT";
      NotifyAccess = "all";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
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
      proxyPass = "https://127.0.0.1:${builtins.toString port}";
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
