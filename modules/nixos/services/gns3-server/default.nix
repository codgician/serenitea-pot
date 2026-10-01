{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "gns3-server";
  cfg = config.codgician.services.gns3-server;
  types = lib.types;
  stateDir = "/var/lib/gns3";
in
{
  options.codgician.services.gns3-server = {
    enable = lib.mkEnableOption "GNS3 Server";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Address GNS3 Server listens on. Device consoles bind to the same address.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3080;
      description = "TCP port GNS3 Server listens on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = stateDir;
      example = "/xpool/appdata/gns3";
      description = "Directory holding GNS3 images, projects, appliances, configs and symbols.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.gns3-server; http://$\{host}:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.gns3-server = {
        enable = true;
        auth = {
          enable = true;
          user = "gns3";
          passwordFile = config.codgician.secrets.files.gns3-server-password.path;
        };
        ubridge.enable = true;
        settings = {
          Server = {
            inherit (cfg) host port;
            report_errors = false;
            appliances_path = "${cfg.dataDir}/appliances";
            configs_path = "${cfg.dataDir}/configs";
            images_path = "${cfg.dataDir}/images";
            projects_path = "${cfg.dataDir}/projects";
            symbols_path = "${cfg.dataDir}/symbols";
          };
        };
      };

      # Upstream only wires QEMU and /dev/kvm when libvirtd is enabled,
      # but GNS3 drives QEMU directly.
      systemd.services.gns3-server = {
        path = [ pkgs.qemu_kvm ];
        serviceConfig = {
          DeviceAllow = [ "/dev/kvm rw" ];
          SupplementaryGroups = [ "kvm" ];
          # QEMU falls back to TCG (JIT) when KVM is unavailable for a guest.
          MemoryDenyWriteExecute = lib.mkForce false;
          ReadWritePaths = lib.mkIf (cfg.dataDir != stateDir) [ cfg.dataDir ];
        };
      };

      systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != stateDir) [
        "d ${cfg.dataDir} 0750 gns3 gns3 -"
      ];

      # /etc/gns3 holds gns3_controller.conf (templates, computes) written at runtime.
      codgician.system.impermanence.extraItems = [
        {
          type = "directory";
          path = "/etc/gns3";
          user = "gns3";
          group = "gns3";
        }
        {
          type = "directory";
          path = stateDir;
          user = "gns3";
          group = "gns3";
        }
      ];
    })

    # Reverse proxy profile
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
        extraVhostConfig.locations."/".passthru.extraConfig = ''
          # Appliance images can be several GB
          client_max_body_size 0;
          proxy_request_buffering off;
          proxy_buffering off;

          # Console and notification websockets idle for long periods
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          send_timeout 3600s;
        '';
      };
    }
  ];
}
