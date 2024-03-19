{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.services.fastapi-dls;
  types = lib.types;
in
{
  options.codgician.services.fastapi-dls = {
    enable = lib.mkEnableOption "Enable fastapi-dls.";

    host = lib.mkOption {
      type = types.str;
      default = "nvdls.codgician.me";
      description = lib.mdDoc ''
        Hostname for fastapi-dls, passed as `--host`.
        Must be a public domain (used for retrieving ACME certificate).
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 4443;
      description = lib.mdDoc ''
        Port for fastapi-dls to listen on, passed as `--port`.
      '';
    };

    announcePort = lib.mkOption {
      type = types.port;
      default = 4443;
      description = lib.mdDoc ''
        Port for fastapi-dls to announce. 
        It may be different than `port` if the service runs behind a reverse proxy.
      '';
    };

    user = lib.mkOption {
      type = types.str;
      default = "fastapi-dls";
      description = lib.mdDoc ''
        User under which fastapi-dls runs.
      '';
    };

    group = lib.mkOption {
      type = types.str;
      default = "fastapi-dls";
      description = lib.mdDoc ''
        Group under which fastapi-dls runs.
      '';
    };

    appDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/fastapi-dls-app";
      description = lib.mdDoc ''
        App directory for fastapi-dls (passed as `--app-dir`).
      '';
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/fastapi-dls-app/data";
      description = lib.mdDoc ''
        Data directory for fastapi-dls (passed as `--app-data`).
      '';
    };

    leaseDays = lib.mkOption {
      type = types.int;
      default = 90;
      description = lib.mdDoc ''
        Expiration days for issued leases.
      '';
    };

    reverseProxy = {
      enable = lib.mkEnableOption "Enable nginx reverse proxy profile for fastapi-dls.";

      https = lib.mkEnableOption "Use https and auto-renew certificates.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        default = [ cfg.host ];
        description = lib.mdDoc ''
          List of domains.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Use fastapi-dls package from xddxdd's NUR
      codgician.overlays.nur.xddxdd.enable = lib.mkForce true;

      # Systemd service for fastapi-dls
      systemd.services.fastapi-dls = {
        enable = true;
        restartIfChanged = true;
        description = "fastapi-dls";
        wantedBy = [ "multi-user.target" ];
        requires = lib.optionals cfg.reverseProxy.https [ "acme-finished-${cfg.host}.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart =
            let
              credsDir = "/run/credentials/fastapi-dls.service";
              envFile = pkgs.writeTextFile {
                name = "fastapi-dls-env";
                text = ''
                  DLS_URL=${cfg.host}
                  DLS_PORT=${builtins.toString cfg.announcePort}
                  LEASE_EXPIRE_DAYS=${builtins.toString cfg.leaseDays}
                  DATABASE=sqlite:///${cfg.dataDir}/db.sqlite
                '';
              };
            in
            ''
              ${pkgs.nur.repos.xddxdd.fastapi-dls}/bin/fastapi-dls \
                --host 127.0.0.1 --port ${builtins.toString cfg.port} \
                --app-dir ${cfg.appDir} \
                --ssl-keyfile ${credsDir}/key.pem --ssl-certfile ${credsDir}/cert.pem \
                --env-file ${envFile} \
                --proxy-headers
            '';
          LoadCredential =
            let certDir = config.security.acme.certs."${cfg.host}".directory; in
            [
              "cert.pem:${certDir}/cert.pem"
              "key.pem:${certDir}/key.pem"
            ];
          WorkingDirectory = cfg.appDir;
          Restart = "always";
          User = cfg.user;
          Group = cfg.group;
          KillSignal = "SIGQUIT";
          NotifyAccess = "all";
          AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        };
      };

      # Create working directory if not exist
      system.activationScripts.makeFastApiDlsAppDir =
        let
          sourceDir = "${pkgs.nur.repos.xddxdd.fastapi-dls}/opt/app";
        in
        lib.stringAfter [ "var" ] ''
          # Link python scripts
          if [ ! -d "${cfg.appDir}" ]; then
            mkdir -p ${cfg.appDir}/cert
          fi
          rm -rf ${cfg.appDir}/main.py
          ln -s ${sourceDir}/main.py ${cfg.appDir}/main.py
          rm -rf ${cfg.appDir}/orm.py     
          ln -s ${sourceDir}/orm.py ${cfg.appDir}/orm.py
          rm -rf ${cfg.appDir}/util.py
          ln -s ${sourceDir}/util.py ${cfg.appDir}/util.py

          # Clean python cache
          rm -rf ${cfg.appDir}/__pycache__

          # Create JWT token
          if [ ! -d "${cfg.dataDir}/cert" ]; then
            mkdir -p ${cfg.dataDir}/cert
          fi
          if [ ! -f "${cfg.dataDir}/cert/instance.private.pem" ]; then 
            ${pkgs.openssl}/bin/openssl genrsa -out ${cfg.dataDir}/cert/instance.private.pem 2048
          fi
          if [ ! -f "${cfg.dataDir}/cert/instance.public.pem" ]; then
            ${pkgs.openssl}/bin/openssl rsa -in ${cfg.dataDir}/cert/instance.private.pem -outform PEM -pubout -out ${cfg.dataDir}/cert/instance.public.pem
          fi
          rm -rf ${cfg.appDir}/cert
          ln -s ${cfg.dataDir}/cert ${cfg.appDir}/cert

          # Fix up permission
          chmod -R 770 ${cfg.appDir}
          chmod -R 770 ${cfg.dataDir}      
          chown -R ${cfg.user}:${cfg.group} ${cfg.appDir}
          chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
        '';

      # User and group
      users = {
        users = lib.mkIf (cfg.user == "fastapi-dls") {
          fastapi-dls = {
            group = cfg.group;
            isSystemUser = true;
          };
        };
        groups = lib.mkIf (cfg.group == "fastapi-dls") {
          fastapi-dls = { };
        };
      };

      # Enable SSL certificate for virtual host
      codgician.acme = lib.mkIf cfg.reverseProxy.https {
        "${cfg.host}" = {
          enable = true;
          extraDomainNames = lib.optionals (cfg.reverseProxy.enable) cfg.reverseProxy.domains;
          postRunScripts = [ "${pkgs.systemd}/bin/systemctl restart fastapi-dls" ];
        };
      };

      # Assertions
      assertions = [
        {
          assertion = !cfg.reverseProxy.enable || !cfg.reverseProxy.https || (config.codgician.acme?"${cfg.host}");
          message = ''Domain "${cfg.host}" must have its certificate retrieval settings added to acme module.'';
        }
      ];
    }

    (lib.mkIf cfg.reverseProxy.enable {
      # Nginx reverse proxy settings
      services.nginx.virtualHosts."${cfg.host}" = {
        locations."/" = {
          proxyPass = "https://127.0.0.1:${builtins.toString cfg.port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
          extraConfig = ''
            proxy_buffering off;
          '' + (lib.optionals cfg.reverseProxy.lanOnly ''
            allow 10.0.0.0/8;
            allow 172.16.0.0/12;
            allow 192.168.0.0/16;
            allow fc00::/7;
            deny all;
          '');
        };

        forceSSL = cfg.reverseProxy.https;
        enableACME = cfg.reverseProxy.https;
        acmeRoot = null;
      };
    }
    )
  ]);
}
