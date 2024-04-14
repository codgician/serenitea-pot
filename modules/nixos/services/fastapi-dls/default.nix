{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.codgician.services.fastapi-dls;
  types = lib.types;
in
{
  options.codgician.services.fastapi-dls = {
    enable = lib.mkEnableOption "Enable fastapi-dls.";

    acmeDomain = lib.mkOption {
      type = types.str;
      default = "nvdls.codgician.me";
      description = lib.mdDoc ''
        Acme domain for fastapi-dls, used to obtain SSL certificate.
        Must be a public domain.
      '';
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = lib.mdDoc ''
        Host for fastapi-dls to listen on, passed as `--host` (IPv4).
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

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for fastapi-dls.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.com" "example.org" ];
        default = [ cfg.acmeDomain ];
        defaultText = ''[ config.codgician.services.fastapi-dls.acmeDomain ]'';
        description = lib.mdDoc ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://${cfg.host}:${toString cfg.port}";
        defaultText = ''http://$\{config.codgician.services.fastapi-dls.host}:$\{toString config.codgician.services.fastapi-dls.port}'';
        description = lib.mdDoc ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    # fastapi-dls configuration
    (lib.mkIf cfg.enable {
      # Use fastapi-dls package from xddxdd's NUR
      codgician.overlays.nur.xddxdd.enable = lib.mkForce true;

      # Systemd service for fastapi-dls
      systemd.services.fastapi-dls = {
        enable = true;
        restartIfChanged = true;
        description = "fastapi-dls";
        wantedBy = [ "multi-user.target" ];
        requires = [ "acme-finished-${cfg.acmeDomain}.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart =
            let
              credsDir = "/run/credentials/fastapi-dls.service";
              envFile = pkgs.writeTextFile {
                name = "fastapi-dls-env";
                text = ''
                  DLS_URL=${cfg.acmeDomain}
                  DLS_PORT=${builtins.toString cfg.announcePort}
                  LEASE_EXPIRE_DAYS=${builtins.toString cfg.leaseDays}
                  DATABASE=sqlite:///${cfg.dataDir}/db.sqlite
                '';
              };
            in
            ''
              ${pkgs.nur.repos.xddxdd.fastapi-dls}/bin/fastapi-dls \
                --host ${cfg.host} --port ${builtins.toString cfg.port} \
                --app-dir ${cfg.appDir} \
                --ssl-keyfile ${credsDir}/key.pem --ssl-certfile ${credsDir}/cert.pem \
                --env-file ${envFile} \
                --proxy-headers
            '';
          LoadCredential =
            let certDir = config.security.acme.certs."${cfg.acmeDomain}".directory; in
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
      codgician.acme = {
        "${cfg.acmeDomain}" = {
          enable = true;
          reloadServices = [ "fastapi-dls" ];
        };
      };
    })

    # Reverse proxy profile
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.fastapi-dls = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      };
    })
  ];
}
