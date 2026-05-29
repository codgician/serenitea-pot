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
  systemd.services.mlx5-sriov =
    let
      pf0Device = "sys-subsystem-net-devices-${getPfName 0}.device";
    in
    {
      description = "Configure Mellanox ConnectX-6 Dx multiport eSwitch and SR-IOV VFs";
      wantedBy = [ pf0Device ];
      bindsTo = [ pf0Device ];
      after = [ pf0Device ];
      before = [ "network.target" ];
      path = with pkgs; [
        iproute2
        coreutils
      ];

      # Don't re-run on `nixos-rebuild switch`: re-running can bounce VF netdevs
      # and disturb VMs holding passthrough VFs. Changes apply on next boot.
      restartIfChanged = false;
      stopIfChanged = false;

      unitConfig = {
        DefaultDependencies = false;
        ConditionPathExists = "/sys/bus/pci/devices/${pciBase}.0";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

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

          # Safe to re-run: same-value writes are kernel no-ops and re-binding a
          # bound VF fails harmlessly (-EBUSY). VF count change (step 4) is guarded.

          # 1. Set lag_port_select_mode on BOTH PFs (must match for LAG)
          echo "Setting lag_port_select_mode=multiport_esw on both PFs..."
          set_lag_mode ${pf0} ${pci0}
          set_lag_mode ${pf1} ${pci1}

          # 2. Switch both PFs to switchdev mode (no-op if already switchdev)
          echo "Switching to switchdev mode..."
          devlink dev eswitch set pci/${pci0} mode switchdev 2>/dev/null || echo "pci/${pci0}: already switchdev or unchanged"
          devlink dev eswitch set pci/${pci1} mode switchdev 2>/dev/null || echo "pci/${pci1}: already switchdev or unchanged"

          # 3. Enable multiport eSwitch (no-op if already enabled)
          echo "Enabling esw_multiport..."
          devlink dev param set pci/${pci0} name esw_multiport value true cmode runtime 2>/dev/null ||
            echo "esw_multiport: already enabled or unchanged"

          # 4. Create VFs on PF0 (skip if already created)
          current_vfs=$(cat /sys/class/net/${pf0}/device/sriov_numvfs)
          if [ "$current_vfs" -eq ${toString numVfs} ]; then
            echo "Already have ${toString numVfs} VFs, skipping creation"
          elif [ "$current_vfs" -ne 0 ]; then
            echo "WARNING: VF count mismatch ($current_vfs != ${toString numVfs}), not tearing down (conservative)"
          else
            echo "Creating ${toString numVfs} VFs..."
            echo ${toString numVfs} > /sys/class/net/${pf0}/device/sriov_numvfs
          fi

          # 5. Set PF-side admin (eSwitch) MAC per VF. The host VF netdev MAC is set
          #    by the .link files below; this is only for eSwitch consistency.
          echo "Configuring VF MAC addresses..."
          ${lib.concatStringsSep "\n" (
            lib.imap0 (i: mac: "ip link set ${pf0} vf ${toString i} mac ${mac}") vfMacs
          )}

          # 6. Unbind passthrough VFs (for VM/container vfio assignment).
          echo "Unbinding passthrough VFs..."
          ${lib.concatMapStringsSep "\n" (
            addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true"
          ) passthruVfPciAddrs}

          # 7. Ensure host VFs are bound (harmless -EBUSY if already bound).
          echo "Binding host VFs..."
          ${lib.concatMapStringsSep "\n" (
            addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true"
          ) hostVfPciAddrs}

          echo "=== Configuration Complete ==="
        '';
    };

  # Set route metric
  systemd.network = {
    config.routeTables.failover = 2048;

    # Pin each host VF's MAC by PCI path so the netdev is born with the right MAC
    # (before carrier), avoiding the duplicate-IPv6-address race. NamePolicy mirrors
    # 99-default.link, else this file suppresses naming and the VF becomes eth0/eth1.
    links = builtins.listToAttrs (
      lib.genList (i: {
        name = "10-${getVfName 0 i}";
        value = {
          matchConfig.Path = "pci-${pciBase}.${toString (i + 2)}";
          linkConfig = {
            MACAddress = builtins.elemAt vfMacs i;
            NamePolicy = "keep kernel database onboard slot path";
          };
        };
      }) hostVfs
    );

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
          DUIDType = "vendor";
          DUIDRawData = "00:00:ab:11:75:d9:96:0e:f8:35:fe:2f";
        };
        ipv6AcceptRAConfig.RouteMetric = 1024;
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
          DUIDType = "vendor";
          DUIDRawData = "00:00:ab:11:75:d9:96:0e:f8:35:fe:0f";
        };
        ipv6AcceptRAConfig.RouteMetric = 2048;
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
