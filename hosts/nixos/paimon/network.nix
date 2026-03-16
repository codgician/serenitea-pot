{ pkgs, ... }:
let
  pciBase = "0000:c1:00";
  devName = "enp193s0";
  getPfBase = x: "${devName}f${builtins.toString x}";
  getPfName = x: "${getPfBase x}np${builtins.toString x}";
  getVfName = x: y: "${getPfBase x}v${builtins.toString y}";
  getVfRepName = x: y: "${getPfBase x}r${builtins.toString y}";
in
{
  # Set up SRIOV VF before running openvswitch
  services.udev.extraRules = ''
    ACTION=="add|move", SUBSYSTEM=="net", NAME=="${getPfName 0}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mlx5-sriov.service"
  '';

  systemd.services.mlx5-sriov = {
    description = "Set up VFs for Mellanox ConnectX-6 Dx NIC.";
    before = [ "network-pre.target" ];
    wantedBy = [
      "network-pre.target"
      "network.target"
    ];
    after = [ "systemd-udevd.service" ];
    path = with pkgs; [
      iproute2
      coreutils
    ];
    unitConfig = {
      DefaultDependencies = false;
      ConditionPathExists = "/sys/bus/pci/devices/${pciBase}.0";
    };
    serviceConfig.Type = "oneshot";

    # Reference: https://gist.github.com/Kamillaova/287c242c57aadc548efdb763243c13c4
    # Sequence: switchdev on ALL PFs -> esw_multiport -> create VFs
    script = ''
      DEV_NAME=${getPfName 0}
      DEV_NAME_PF1=${getPfName 1}
      DEV_PCIBASE=${pciBase}

      # Wait for both PF devices to appear
      for i in {1..100}; do
        if [ -e "/sys/class/net/$DEV_NAME" ] && [ -e "/sys/class/net/$DEV_NAME_PF1" ]; then
          break
        fi
        sleep 0.1
      done

      # Step 1: Set eSwitch mode to switchdev on BOTH PFs
      echo "Setting eSwitch mode to switchdev on both PFs ..."
      devlink dev eswitch set pci/''${DEV_PCIBASE}.0 mode switchdev
      devlink dev eswitch set pci/''${DEV_PCIBASE}.1 mode switchdev

      # Step 2: Enable esw_multiport via devlink on BOTH PFs
      echo "Enabling esw_multiport on both PFs ..."
      devlink dev param set pci/''${DEV_PCIBASE}.0 name esw_multiport value 1 cmode runtime
      devlink dev param set pci/''${DEV_PCIBASE}.1 name esw_multiport value 1 cmode runtime
      echo "esw_multiport PF0: $(devlink dev param show pci/''${DEV_PCIBASE}.0 name esw_multiport 2>&1 | grep -o 'value [a-z]*' | tail -1)"
      echo "esw_multiport PF1: $(devlink dev param show pci/''${DEV_PCIBASE}.1 name esw_multiport 2>&1 | grep -o 'value [a-z]*' | tail -1)"

      # Step 3: Create VFs on PF0
      echo "Creating 6 VFs on $DEV_NAME ..."
      echo 6 > /sys/class/net/$DEV_NAME/device/sriov_numvfs

      # Step 4: Set MAC addresses for VFs
      echo "Setting MAC addresses for VFs ..."
      ip link set $DEV_NAME vf 0 mac ac:79:86:9a:13:02
      ip link set $DEV_NAME vf 1 mac ac:79:86:2a:81:da
      ip link set $DEV_NAME vf 2 mac ac:79:86:28:02:91
      ip link set $DEV_NAME vf 3 mac ac:79:86:92:0b:af
      ip link set $DEV_NAME vf 4 mac ac:79:86:32:a1:21
      ip link set $DEV_NAME vf 5 mac ac:79:86:7e:27:1f

      # Step 5: Unbind VFs (so they can be assigned to VMs/containers)
      echo "Unbinding VFs from driver ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.4 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.5 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.6 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.7 > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true

      # Step 6: Bind first two VFs to host
      echo "Binding first two VFs to host ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true

      # Report final state
      echo "=== Final State ==="
      echo "VFs: $(cat /sys/class/net/$DEV_NAME/device/sriov_numvfs)"
      echo "esw_multiport: $(devlink dev param show pci/''${DEV_PCIBASE}.0 name esw_multiport 2>&1 | grep -o 'value [a-z]*' | tail -1)"
    '';
  };

  # Set route metric
  systemd.network = {
    config.routeTables.failover = 2048;
    networks = {
      # High speed NIC (first VF for host)
      "10-${getVfName 0 0}" = {
        name = getVfName 0 0;
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

      # Leave second VF unconfigured for container
      "11-${getVfName 0 1}" = {
        name = getVfName 0 1;
        linkConfig.Unmanaged = "yes";
      };

      # Management NIC
      "12-eno1" = {
        name = "eno1";
        networkConfig = {
          DHCP = "yes";
          IPv6PrivacyExtensions = "kernel";
        };
        dhcpV4Config = {
          RouteMetric = 2048;
          UseRoutes = "no";
        };
        dhcpV6Config = {
          RouteMetric = 2048;
          DUIDType = "vendor";
          DUIDRawData = "00:00:ab:11:75:d9:96:0e:f8:35:fe:0f";
        };
        linkConfig.RequiredForOnline = "no-carrier";
        routes = [
          {
            Gateway = "_dhcp4";
            Table = 2048;
          }
        ];
        routingPolicyRules = [
          {
            From = "192.168.0.21/32";
            Table = 2048;
            Priority = 200;
          }
        ];
      };
    };
  };

  # Use openvswitch
  codgician.virtualization.vswitch = {
    enable = true;
    extraGlobalOptions = [
      "other_config:hw-offload=true"
      "other_config:max-idle=30000"
      "other_config:max-revalidator=10000"
      "other_config:n-handler-threads=4"
      "other_config:n-revalidator-threads=4"
      # Prevent `tc mirred to Houston: device vs0 is down` flooding dmesg
      "other_config:tc-policy=skip_sw"
    ];
    switches.vs0 = {
      interfaces = {
        # PFs
        ${getPfName 0} = { };
        ${getPfName 1} = { };
        # VFs
        ${getVfRepName 0 0} = { };
        ${getVfRepName 0 1} = { };
        ${getVfRepName 0 2} = { };
        ${getVfRepName 0 3} = { };
        ${getVfRepName 0 4} = { };
        ${getVfRepName 0 5} = { };
      };
    };
  };

  # Hack: let pve-manager know the existence of vs0 vswitch
  # We don't use ifupdown2 to manage network interface so this has no effect
  environment.etc."/network/interfaces".text = ''
    allow-ovs vs0
    iface vs0 inet manual
      ovs_type OVSBridge
  '';
}
