{
  config,
  pkgs,
  lib,
  ...
}:
let
  pciBase = "0000:c1:00";
  devName = "enp193s0";
  getPfBase = x: "${devName}f${builtins.toString x}";
  getPfName = x: "${getPfBase x}np${builtins.toString x}";
  getVfName = x: y: "${getPfBase x}v${builtins.toString y}";
  getVfRepName = x: y: "${getPfBase x}r${builtins.toString y}";

  # VF configuration: index -> MAC address
  vfMacs = [
    "ac:79:86:9a:13:02" # host
    "ac:79:86:2a:81:da" # nahida
    "ac:79:86:28:02:91" # zhongli (passthrough)
    "ac:79:86:92:0b:af" # guoba (passthrough)
    "ac:79:86:5a:1d:e2" # raiden-ei (vDPA)
    "ac:79:86:12:ef:fa" # ineffa
  ];
  numVfs = builtins.length vfMacs;
  hostVfs = 2; # Number of VFs to keep bound for host use
  vfPciAddr = i: "${pciBase}.${toString (i + 2)}";

  # macOS has no driver for the VF, so raiden-ei gets it as a virtio-net device
  # through hardware vDPA. Its PVE args must pass the same MAC (QEMU mac=):
  # QEMU programs that MAC into the device when the VM starts. The VM also
  # needs hookscript-vdpa.sh (proxmox.nix) to lift QEMU's memlock limit.
  vdpa = {
    name = "raiden-ei";
    vf = 4;
  };
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

      # Multiport eSwitch setup sequence (inbox mlx5, esw_multiport devlink param):
      # https://docs.kernel.org/networking/devlink/mlx5.html
      #
      # Prerequisites:
      #   - LAG_RESOURCE_ALLOCATION=1 in firmware (mlxconfig)
      #   - Both PFs start in legacy mode
      #
      # Order:
      #   1. Switch BOTH PFs to switchdev mode
      #   2. Enable esw_multiport (activates LAG with shared FDB)
      #   3. Create VFs
      script =
        let
          pf0 = getPfName 0;
          pci0 = "${pciBase}.0";
          pci1 = "${pciBase}.1";
          vfPciAddrs = map vfPciAddr (lib.range 0 (numVfs - 1));
          hostVfPciAddrs = lib.take hostVfs vfPciAddrs;
          passthruVfPciAddrs = lib.remove (vfPciAddr vdpa.vf) (lib.drop hostVfs vfPciAddrs);
        in
        ''
          set -euo pipefail

          # Safe to re-run: same-value writes are kernel no-ops and re-binding a
          # bound VF fails harmlessly (-EBUSY). VF count change (step 3) is guarded.

          # 1. Switch both PFs to switchdev mode (no-op if already switchdev)
          echo "Switching to switchdev mode..."
          devlink dev eswitch set pci/${pci0} mode switchdev 2>/dev/null || echo "pci/${pci0}: already switchdev or unchanged"
          devlink dev eswitch set pci/${pci1} mode switchdev 2>/dev/null || echo "pci/${pci1}: already switchdev or unchanged"

          # 2. Enable multiport eSwitch (no-op if already enabled)
          echo "Enabling esw_multiport..."
          devlink dev param set pci/${pci0} name esw_multiport value true cmode runtime 2>/dev/null ||
            echo "esw_multiport: already enabled or unchanged"

          # 3. Create VFs on PF0 (skip if already created)
          current_vfs=$(cat /sys/class/net/${pf0}/device/sriov_numvfs)
          if [ "$current_vfs" -eq ${toString numVfs} ]; then
            echo "Already have ${toString numVfs} VFs, skipping creation"
          elif [ "$current_vfs" -ne 0 ]; then
            echo "WARNING: VF count mismatch ($current_vfs != ${toString numVfs}), not tearing down (conservative)"
          else
            echo "Creating ${toString numVfs} VFs..."
            echo ${toString numVfs} > /sys/class/net/${pf0}/device/sriov_numvfs
          fi

          # 4. Set PF-side admin (eSwitch) MAC per VF. The host VF netdev MAC is set
          #    by the .link files below; this is only for eSwitch consistency.
          echo "Configuring VF MAC addresses..."
          ${lib.concatStringsSep "\n" (
            lib.imap0 (i: mac: "ip link set ${pf0} vf ${toString i} mac ${mac}") vfMacs
          )}

          # 5. Unbind passthrough VFs (for VM/container vfio assignment).
          echo "Unbinding passthrough VFs..."
          ${lib.concatMapStringsSep "\n" (
            addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/unbind 2>/dev/null || true"
          ) passthruVfPciAddrs}

          # 6. Ensure host VFs are bound (harmless -EBUSY if already bound).
          echo "Binding host VFs..."
          ${lib.concatMapStringsSep "\n" (
            addr: "echo ${addr} > /sys/bus/pci/drivers/mlx5_core/bind 2>/dev/null || true"
          ) hostVfPciAddrs}

          echo "=== Configuration Complete ==="
        '';
    };

  systemd.services."vdpa-${vdpa.name}" =
    let
      pci = vfPciAddr vdpa.vf;
      mac = builtins.elemAt vfMacs vdpa.vf;
    in
    {
      description = "Hardware vDPA virtio-net device for ${vdpa.name}";
      wantedBy = [ "multi-user.target" ];
      requires = [ "mlx5-sriov.service" ];
      after = [ "mlx5-sriov.service" ];
      before = [ "pve-guests.service" ];
      path = with pkgs; [
        iproute2
        kmod
        coreutils
      ];

      # Deleting the device blocks while the VM holds it open. Changes apply on
      # next boot, or by restarting this unit while the VM is stopped.
      restartIfChanged = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        wait_for() {
          for _ in $(seq 100); do
            "$@" >/dev/null 2>&1 && return 0
            sleep 0.1
          done
          echo "Timed out waiting for: $*" >&2
          return 1
        }

        if ! vdpa dev show ${vdpa.name} >/dev/null 2>&1; then
          vf=/sys/bus/pci/devices/${pci}
          ip link set ${getPfName 0} vf ${toString vdpa.vf} mac ${mac}

          # PVE registers this VF model with vfio-pci (new_id) whenever it starts
          # a VM with a passthrough VF, so pin this one to mlx5_core.
          echo mlx5_core > $vf/driver_override
          if [ -e $vf/driver ] && [ "$(basename "$(readlink $vf/driver)")" != mlx5_core ]; then
            echo ${pci} > $vf/driver/unbind
          fi
          [ -e $vf/driver ] || echo ${pci} > /sys/bus/pci/drivers_probe

          # Keep only the vnet (vDPA) function: no host netdev or RDMA device
          wait_for devlink dev show pci/${pci}
          devlink dev param set pci/${pci} name enable_eth value false cmode driverinit
          devlink dev param set pci/${pci} name enable_rdma value false cmode driverinit
          devlink dev reload pci/${pci}

          # Load vhost_vdpa first so the device binds to it on creation. macOS
          # does not negotiate multiqueue, so one queue pair is enough.
          modprobe vhost_vdpa
          wait_for vdpa mgmtdev show pci/${pci}
          vdpa dev add name ${vdpa.name} mgmtdev pci/${pci} mac ${mac} max_vqp 1
        fi

        dev=/sys/bus/vdpa/devices/${vdpa.name}
        wait_for test -e $dev/driver
        drv=$(basename "$(readlink $dev/driver)")
        if [ "$drv" != vhost_vdpa ]; then
          echo "${vdpa.name} is bound to $drv, expected vhost_vdpa" >&2
          exit 1
        fi

        # Stable path for the PVE args: the vhost-vdpa-N index follows creation order
        chardev=/dev/$(basename $dev/vhost-vdpa-*)
        wait_for test -c $chardev
        mkdir -p /run/vdpa
        ln -sfn $chardev /run/vdpa/${vdpa.name}
      '';

      preStop = ''
        rm -f /run/vdpa/${vdpa.name}
        vdpa dev del ${vdpa.name}
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
          matchConfig.Path = "pci-${vfPciAddr i}";
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

      # vDPA VF: its netdev only lives until the vdpa unit disables it
      "11-${getVfName 0 vdpa.vf}" = {
        matchConfig.Path = "pci-${vfPciAddr vdpa.vf}";
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
