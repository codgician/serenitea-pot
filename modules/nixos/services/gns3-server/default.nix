{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.gns3-server;
  port = 3080;
  stateDir = "/var/lib/gns3";
in
{
  options.codgician.services.gns3-server = {
    enable = lib.mkEnableOption "GNS3 server";
    package = lib.mkPackageOption pkgs "gns3-server" { };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = stateDir;
      example = "/xpool/appdata/gns3";
      description = "Directory holding GNS3 images, projects, appliances, configs and symbols.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.gns3-server.proxyPass = "http://127.0.0.1:${toString port}";

      services.gns3-server = {
        enable = true;
        inherit (cfg) package;
        auth = {
          enable = true;
          user = "gns3";
          passwordFile = config.codgician.secrets.files.gns3-server-password.path;
        };
        ubridge.enable = true;
        settings = {
          Server = {
            # Device consoles bind to the same address.
            host = "127.0.0.1";
            inherit port;
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

    {
      codgician.services.nginx.reverseProxies.gns3-server = {
        domains = [ "miliastra.${lib.codgician.zone}" ];
        authelia.groups = [ "gns3" ];
        locations."/".extraConfig = ''
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
