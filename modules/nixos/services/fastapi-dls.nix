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
      example = "nvdls.example.com";
      description = lib.mdDoc "Hostname for fastapi-dls, passed as `--host`.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 4443;
      description = lib.mdDoc "Port for fastapi-dls to listen on, passed as `--port`.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "fastapi-dls";
      description = lib.mdDoc "User under which fastapi-dls runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "fastapi-dls";
      description = lib.mdDoc "Group under which fastapi-dls runs.";
    };

    appDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/fastapi-dls-app";
      description = lib.mdDoc "App directory for fastapi-dls (passed as `--app-dir`).";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/fastapi-dls-app/data";
      description = lib.mdDoc "Data directory for fastapi-dls (passed as `--app-data`).";
    };

    leaseDays = lib.mkOption {
      type = types.int;
      default = 90;
      description = lib.mdDoc "Expiration days for issued leases.";
    };

    reverseProxy = {
      enable = lib.mkEnableOption "Enable nginx reverse proxy profile for fastapi-dls.";

      https = lib.mkEnableOption "Use https and auto-renew certificates.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "nvdls.example.com" ];
        default = [ cfg.host ];
        description = lib.mdDoc "List of domains. The first one will be treated as virtual host name.";
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config =
    let
      virtualHost = builtins.elemAt cfg.reverseProxy.domains 0;
    in
    lib.mkIf cfg.enable {
      # Use fastapi-dls package from xddxdd's NUR
      codgician.overlays.nur.xddxdd.enable = lib.mkForce true;

      # Systemd service for fastapi-dls
      systemd.services.fastapi-dls = {
        enable = true;
        restartIfChanged = true;
        description = "fastapi-dls";
        wantedBy = [ "multi-user.target" ];
        requires = lib.optionals cfg.reverseProxy.https [ "acme-finished-${virtualHost}.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart =
            let
              credsDir = "/run/credentials/fastapi-dls.service";
              envFile = pkgs.writeTextFile {
                name = "fastapi-dls-env";
                text = ''
                  DLS_URL=${cfg.host}
                  DLS_PORT=${builtins.toString cfg.port}
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
            let certDir = config.security.acme.certs."${virtualHost}".directory; in
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

      # # User and group
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

      # Nginx reverse proxy settings
      services.nginx.virtualHosts."${virtualHost}" = lib.mkIf cfg.reverseProxy.enable {
        locations."/" = {
          proxyPass = "https://127.0.0.1:${builtins.toString cfg.port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
          extraConfig = ''
            proxy_buffering off;
          '' + (lib.optionals cfg.reverseProxy.lanOnly ''
            deny all;
            allow 10.0.0.0/8;
            allow 172.16.0.0/12;
            allow 192.168.0.0/16;
            allow fc00::/7;
          '');
        };

        forceSSL = cfg.reverseProxy.https;
        enableACME = cfg.reverseProxy.https;
        acmeRoot = null;
      };

      # SSL certificate
      security.acme.certs."${virtualHost}" = {
        domain = virtualHost;
        extraDomainNames = builtins.tail cfg.reverseProxy.domains;
        group = config.services.nginx.user;

        # Load new certificate
        postRun = ''
          ${pkgs.systemd}/bin/systemctl restart fastapi-dls
        '';
      };
    };
}
