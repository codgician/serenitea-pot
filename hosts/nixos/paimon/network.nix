{ pkgs, ... }:
{

  # Set up SRIOV VF before running openvswitch
  systemd.services.mlx5-sriov = {
    enable = true;
    description = "Set up VFs for Mellanox ConnectX-5 NIC.";
    wantedBy = [ "ovs-vswitchd.service" ];
    after = [ "systemd-udev-settle.service" ];
    path = with pkgs; [ iproute2 ];
    # Doc: https://docs.nvidia.com/networking/display/mlnxofedv24100700/ovs+offload+using+asap²+direct
    script = ''
      DEV_NAME=enp67s0f0np0
      DEV_PCIBASE=0000:43:00

      # Set number of VFs
      echo "Creating 6 VFs for $DEV_NAME ..."
      echo 6 > /sys/class/net/$DEV_NAME/device/sriov_numvfs

      # Set MAC addresses for VFs
      echo "Setting MAC addresses for VFs ..."
      ip link set $DEV_NAME vf 0 mac ac:79:86:9a:13:02
      ip link set $DEV_NAME vf 1 mac ac:79:86:2a:81:da
      ip link set $DEV_NAME vf 2 mac ac:79:86:28:02:91
      ip link set $DEV_NAME vf 3 mac ac:79:86:92:0b:af
      ip link set $DEV_NAME vf 4 mac ac:79:86:7e:27:1f
      ip link set $DEV_NAME vf 5 mac ac:79:86:5a:2d:03

      # Unbind VFs
      echo "Unbinding VFs from driver ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.4 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.5 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.6 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.7 > /sys/bus/pci/drivers/mlx5_core/unbind

      # Set DMFS
      devlink dev param set pci/''${DEV_PCIBASE}.0 name flow_steering_mode value "dmfs" cmode runtime
      devlink dev param set pci/''${DEV_PCIBASE}.1 name flow_steering_mode value "dmfs" cmode runtime

      # Enable eSwitch
      echo "Setting eSwitch mode to switchdev ..."
      devlink dev eswitch set pci/''${DEV_PCIBASE}.0 mode switchdev
      devlink dev eswitch set pci/''${DEV_PCIBASE}.1 mode switchdev

      # Bind first VF to host
      echo "Binding first VF to host ..."
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/bind

      # Bind second VF for container nahida
      echo "Binding second VF to host ..."
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/bind
    '';
    serviceConfig.Type = "oneshot";
  };

  # Set route metric
  systemd.network.networks = {
    # High speed NIC (first VF for host)
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

    # Leave second VF unconfigured for container
    "11-enp67s0f0v1" = {
      name = "enp67s0f0v1";
      linkConfig.Unmanaged = "yes";
    };

    # Fallback NIC
    "12-eno1" = {
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
      "other_config:max-idle=30000"
      "other_config:max-revalidator=10000"
      "other_config:n-handler-threads=4"
      "other_config:n-revalidator-threads=4"
      # Prevent `tc mirred to Houston: device vs0 is down` flooding dmesg
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
        enp67s0f0r4 = { };
        enp67s0f0r5 = { };
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
