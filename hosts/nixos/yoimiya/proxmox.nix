{ pkgs, ... }:
{
  # Enable proxmox VE
  services.proxmox-ve = {
    enable = true;
    ipAddress = "192.168.0.21";
  };

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
      echo 4 > /sys/class/net/$DEV_NAME/device/sriov_numvfs

      # Set MAC addresses for VFs
      ip link set $DEV_NAME vf 0 mac ac:79:86:90:31:9a
      ip link set $DEV_NAME vf 1 mac ac:79:86:2a:81:da
      ip link set $DEV_NAME vf 2 mac ac:79:86:28:02:91
      ip link set $DEV_NAME vf 3 mac ac:79:86:92:0b:af

      # Unbind VFs
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.3 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.4 > /sys/bus/pci/drivers/mlx5_core/unbind
      echo ''${DEV_PCIBASE}.5 > /sys/bus/pci/drivers/mlx5_core/unbind

      # Enable eSwitch
      devlink dev eswitch set pci/''${DEV_PCIBASE}.0 mode switchdev

      # Bind first VF to host
      echo ''${DEV_PCIBASE}.2 > /sys/bus/pci/drivers/mlx5_core/bind
    '';
    serviceConfig.Type = "oneshot";
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
  systemd.services.pvedaemon.path = with pkgs; [ swtpm ];
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
}
