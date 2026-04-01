{ pkgs, lib, ... }:
let
  pciBase = "0000:c1:00";
  devName = "enp193s0";
  getPfBase = x: "${devName}f${builtins.toString x}";
  getPfName = x: "${getPfBase x}np${builtins.toString x}";
  getVfName = x: y: "${getPfBase x}v${builtins.toString y}";
  getVfRepName = x: y: "${getPfBase x}r${builtins.toString y}";

  # VF configuration: index -> MAC address
  vfMacs = [
    "ac:79:86:9a:13:02"
    "ac:79:86:2a:81:da"
    "ac:79:86:28:02:91"
    "ac:79:86:92:0b:af"
    "ac:79:86:32:a1:21"
    "ac:79:86:7e:27:1f"
  ];
  numVfs = builtins.length vfMacs;
  hostVfs = 2; # Number of VFs to keep bound for host use
in
{
  # Trigger mlx5-sriov service when PF0 appears
  services.udev.extraRules = ''
    ACTION=="add|move", SUBSYSTEM=="net", NAME=="${getPfName 0}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mlx5-sriov.service"
  '';

  systemd.services.mlx5-sriov = {
    description = "Configure Mellanox ConnectX-6 Dx multiport eSwitch and SR-IOV VFs";
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

    # Multiport eSwitch setup sequence (per Mellanox ovs-tests reference):
    # https://github.com/Mellanox/ovs-tests/blob/master/test-ovs-multiport-esw-mode.sh
    #
    # Prerequisites:
    #   - LAG_RESOURCE_ALLOCATION=1 in firmware (mlxconfig)
    #   - Both PFs start in legacy mode
    #
    # Order:
    #   1. Set lag_port_select_mode=multiport_esw on BOTH PFs (legacy mode)
    #   2. Switch BOTH PFs to switchdev mode
    #   3. Enable esw_multiport (activates LAG with shared FDB)
    #   4. Create VFs
    script =
      let
        pf0 = getPfName 0;
        pf1 = getPfName 1;
        pci0 = "${pciBase}.0";
        pci1 = "${pciBase}.1";
        vfPciAddrs = map (i: "${pciBase}.${toString (i + 2)}") (lib.range 0 (numVfs - 1));
        hostVfPciAddrs = lib.take hostVfs vfPciAddrs;
        passthruVfPciAddrs = lib.drop hostVfs vfPciAddrs;
      in
      ''
        set -euo pipefail

        # Helper: set lag_port_select_mode via sysfs (preferred) or devlink
        set_lag_mode() {
          local dev=$1 pci=$2
          echo multiport_esw > "/sys/class/net/$dev/compat/devlink/lag_port_select_mode" 2>/dev/null ||
            devlink dev param set "pci/$pci" name lag_port_select_mode value multiport_esw cmode runtime 2>/dev/null ||
            echo "WARNING: Failed to set lag_port_select_mode on $dev"
        }

        # 1. Set lag_port_select_mode on BOTH PFs (must match for LAG)
        echo "Setting lag_port_select_mode=multiport_esw on both PFs..."
        set_lag_mode ${pf0} ${pci0}
        set_lag_mode ${pf1} ${pci1}

        # 2. Switch both PFs to switchdev mode
        echo "Switching to switchdev mode..."
        devlink dev eswitch set pci/${pci0} mode switchdev
        devlink dev eswitch set pci/${pci1} mode switchdev

        # 3. Enable multiport eSwitch (creates LAG with shared FDB)
        echo "Enabling esw_multiport..."
        if ! devlink dev param set pci/${pci0} name esw_multiport value true cmode runtime; then
          echo "ERROR: Failed to enable esw_multiport"
          echo "Hint: Check 'dmesg | grep -iE \"(lag|mpesw|shared_fdb)\"'"
          exit 1
        fi

        # 4. Create VFs on PF0
        echo "Creating ${toString numVfs} VFs..."
        echo ${toString numVfs} > /sys/class/net/${pf0}/device/sriov_numvfs

        # 5. Set MAC addresses
        echo "Configuring VF MAC addresses..."
        ${lib.concatStringsSep "\n" (
          lib.imap0 (i: mac: "ip link set ${pf0} vf ${toString i} mac ${mac}") vfMacs
        )}

        # 6. Unbind passthrough VFs (for VM/container assignment)
        echo "Unbinding passthrough VFs..."
        ${lib.concatMapStringsSep "\n" (
          addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true"
        ) passthruVfPciAddrs}

        # 7. Ensure host VFs are bound
        echo "Binding host VFs..."
        ${lib.concatMapStringsSep "\n" (
          addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true"
        ) hostVfPciAddrs}

        # 8. Set MAC addresses on host VF netdevs
        # (ip link set PF vf N mac X only sets admin MAC; host-bound VFs need direct config)
        echo "Configuring host VF MAC addresses..."
        ${lib.concatStringsSep "\n" (
          lib.imap0 (i: mac: "ip link set ${getVfName 0 i} address ${mac}") (lib.take hostVfs vfMacs)
        )}

        # Report status
        echo "=== Configuration Complete ==="
        echo "VFs created: $(cat /sys/class/net/${pf0}/device/sriov_numvfs)"
        echo "esw_multiport: $(devlink dev param show pci/${pci0} name esw_multiport 2>&1 | grep -oP 'value \K\w+' || echo unknown)"
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
      "other_config:max-revalidator=2000"
      # Prevent `tc mirred to Houston: device vs0 is down` flooding dmesg
      "other_config:tc-policy=skip_sw"
    ];
    switches.vs0 = {
      interfaces = {
        # PFs
        ${getPfName 0} = { };
        ${getPfName 1} = { };
        # VF representors
        ${getVfRepName 0 0} = { };
        ${getVfRepName 0 1} = { };
        ${getVfRepName 0 2} = { };
        ${getVfRepName 0 3} = { };
        ${getVfRepName 0 4} = { };
        ${getVfRepName 0 5} = { };
      };
    };
  };

  # Prevent ARP flux: two NICs (eno1 + VF0) share the same subnet as failover,
  # so restrict each interface to only respond to ARPs for its own address.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
  };

  # Hack: let pve-manager know the existence of vs0 vswitch
  # We don't use ifupdown2 to manage network interface so this has no effect
  environment.etc."/network/interfaces".text = ''
    allow-ovs vs0
    iface vs0 inet manual
      ovs_type OVSBridge
  '';
}
