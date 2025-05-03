{
  config,
  lib,
  pkgs,
  ...
}:
let
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  # Enable Proxmox VE
  networking.firewall.allowedTCPPorts = [ 8006 ];
  services.proxmox-ve = {
    enable = true;
    ipAddress = "192.168.0.21";
  };

  # Reverse proxy
  codgician = {
    services.nginx = {
      enable = true;
      openFirewall = true;
      reverseProxies = {
        "pve.codgician.me" = {
          enable = true;
          https = true;
          domains = [ "pve.codgician.me" ];
          locations."/".proxyPass = "https://127.0.0.1:8006";
        };
      };
    };
    acme."pve.codgician.me".postRun = ''
      cp -f cert.pem /etc/pve/local/pveproxy-ssl.pem
      cp -f key.pem /etc/pve/local/pveproxy-ssl.key
      systemctl restart pveproxy.service
    '';
  };

  # Impermenance for Proxmox VE
  environment.persistence.${impermanenceCfg.path}.directories = lib.mkIf impermanenceCfg.enable [
    "/var/lib/pve-cluster"
    "/var/lib/pve-firewall"
    "/var/lib/pve-manager"
  ];

  # Set up SRIOV VF before running openvswitch
  systemd.services.mlx5-sriov = {
    enable = true;
    description = "Set up VFs for Mellanox ConnectX-4/5 NICs.";
    wantedBy = [ "ovs-vswitchd.service" ];
    after = [ "systemd-udev-settle.service" ];
    path = with pkgs; [ iproute2 ];
    script = ''
      DEV_NAME=enp67s0f0np0
      DEV_PCIBASE=0000:43:00

      # Set number of VFs
      echo "Creating 4 VFs for $DEV_NAME ..."
      echo 4 > /sys/class/net/$DEV_NAME/device/sriov_numvfs

      # Set MAC addresses for VFs
      echo "Setting MAC addresses for VFs ..."
      ip link set $DEV_NAME vf 0 mac ac:79:86:9a:13:02
      ip link set $DEV_NAME vf 1 mac ac:79:86:2a:81:da
      ip link set $DEV_NAME vf 2 mac ac:79:86:28:02:91
      ip link set $DEV_NAME vf 3 mac ac:79:86:92:0b:af

      # Unbind VFs
      echo "Unbinding VFs from driver ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.4 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.5 > /sys/bus/pci/drivers/mlx5_core/unbind

      # Enable eSwitch
      echo "Setting eSwitch mode to switchdev ..."
      devlink dev eswitch set pci/''${DEV_PCIBASE}.0 mode switchdev

      # Bind first VF to host
      echo "Binding first VF to host ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/bind
    '';
    serviceConfig.Type = "oneshot";
  };

  # Set route metric
  systemd.network.networks = {
    "10-enp67s0f0v0" = {
      name = "enp67s0f0v0";
      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = "kernel";
      };
      dhcpV4Config.RouteMetric = 1024;
      dhcpV6Config = {
        RouteMetric = 1024;
        DUIDType = "vendor";
        DUIDRawData = "00:00:ab:11:75:d9:96:0e:f8:35:fe:2f";
      };
      linkConfig.RequiredForOnline = "no-carrier";
    };
    "11-eno1" = {
      name = "eno1";
      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = "kernel";
      };
      dhcpV4Config.RouteMetric = 2048;
      dhcpV6Config = {
        RouteMetric = 2048;
        DUIDType = "vendor";
        DUIDRawData = "00:00:ab:11:75:d9:96:0e:f8:35:fe:0f";
      };
      linkConfig.RequiredForOnline = "no-carrier";
    };
  };

  # Use openvswitch
  codgician.virtualization.vswitch = {
    enable = true;
    extraGlobalOptions = [
      "other_config:hw-offload=true"
      "other_config:tc-policy=skip_sw"
    ];
    switches.vs0 = {
      interfaces = {
        enp67s0f0np0 = { };
        enp67s0f1np1 = { };
        # VFs
        enp67s0f0r0 = { };
        enp67s0f0r1 = { };
        enp67s0f0r2 = { };
        enp67s0f0r3 = { };
      };
    };
  };

  # swtpm setup
  environment.systemPackages = with pkgs; [ swtpm ];
  systemd.services = {
    pvedaemon.path = with pkgs; [ swtpm ];
    pve-guests.path = with pkgs; [ swtpm ];
  };
  environment.etc."swtpm_setup.conf".text = ''
    # Program invoked for creating certificates
    create_certs_tool= ${pkgs.swtpm}/share/swtpm/swtpm-localca
    create_certs_tool_config = ${pkgs.writeText "swtpm-localca.conf" ''
      statedir = /var/lib/swtpm-localca
      signingkey = /var/lib/swtpm-localca/signkey.pem
      issuercert = /var/lib/swtpm-localca/issuercert.pem
      certserial = /var/lib/swtpm-localca/certserial
    ''}
    create_certs_tool_options = ${pkgs.swtpm}/etc/swtpm-localca.options
    # Comma-separated list (no spaces) of PCR banks to activate by default
    active_pcr_banks = sha256
  '';

  # hookscript snippets
  environment.etc."pve-snippets/snippets/hookscript-guoba.sh".source = lib.getExe (
    pkgs.writeShellApplication {
      name = "hookscript";
      runtimeInputs = with pkgs; [ systemd ];
      text = ''
        USAGE="Usage: $0 vmid phase"
        if [ "$#" -ne "2" ]; then
          echo "Expect 2 arguments, got $#"
          echo "$USAGE"
          exit 1
        fi

        echo "GUEST HOOK: $0 $*"
        vmid=$1
        if ! [[ $vmid =~ ^-?[0-9]+$ ]]; then
          echo "Expect vmid to be a number, got $vmid"
          exit 1
        fi
        phase=$2
        case "''${phase}" in
          pre-start|post-start|pre-stop|post-stop) : ;;
          *) echo "Got unknown phase ''${phase}"; exit 1 ;;
        esac

        case "''${phase}" in
          pre-start)  
            echo "''${vmid} is starting, running pre-start hookscripts..."
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-7,16-39,48-63
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-7,16-39,48-63
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-7,16-39,48-63
            ;;
          pre-stop)
            echo "''${vmid} stopped, running post-stop hookscripts..."
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-63
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-63
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-63
            ;;
        esac
      '';
    }
  );
}
