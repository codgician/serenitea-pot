{ pkgs, ... }:
let
  # Public addresses; the records in packages/terraform-config repeat them.
  publicIpv4 = "129.28.44.172";
  publicIpv6 = "2402:4e00:c000:2300:aa68:cd10:e82c:0";
  # Tencent's stable DHCP address, mapped 1:1 to the public IPv4 address.
  privateIpv4 = "10.6.4.16";
in
{
  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "xhci_pci"
      "virtio_blk"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];

    kernelPackages = pkgs.linuxPackages_6_18;
    zfs.package = pkgs.zfs_2_4;

    # The default /dev/disk/by-id is empty in Tencent CVM
    zfs.devNodes = "/dev/disk/by-path";
  };

  fileSystems."/persist".neededForBoot = true;

  # Enable cloud-init
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig.Restart = "on-failure";

  # Manually configure IPv6 network on Tencent Cloud using systemd-networkd
  #
  # Tencent Cloud's virtual gateway (fe80::feee:ffff:feff:ffff / fe:ee:0f:11:b8:0a)
  # responds to DAD Neighbor Solicitations for addresses it has assigned, causing
  # false "duplicate address detected" failures. We must disable DAD entirely:
  # - IPv6DuplicateAddressDetection=0: don't send DAD probes (systemd-networkd)
  # - accept_dad=0: don't process incoming DAD responses (kernel sysctl)
  boot.kernel.sysctl."net.ipv6.conf.eth0.accept_dad" = 0;

  networking.usePredictableInterfaceNames = false;
  systemd.network.networks."40-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6DuplicateAddressDetection = 0;
      # Accept Router Advertisements even with forwarding enabled (needed for gateway discovery)
      IPv6AcceptRA = true;
    };
    # Static IPv6 address from Tencent Cloud
    addresses = [
      {
        Address = "${publicIpv6}/128";
        DuplicateAddressDetection = "none";
      }
    ];
    # IPv6 default route via Tencent Cloud's link-local gateway
    routes = [
      {
        Destination = "::/0";
        Gateway = "fe80::feee:ffff:feff:ffff";
        GatewayOnLink = true;
      }
    ];
  };

  # The TURN relay binds the addresses of this interface.
  codgician.services.coturn = {
    relay-ips = [
      privateIpv4
      publicIpv6
    ];
    external-ips = [ "${publicIpv4}/${privateIpv4}" ];
  };

  # Override distro in cloud-init
  services.cloud-init = {
    extraPackages = with pkgs; [ zfs ];
    settings = {
      preserve_hostname = true;
      network.config = "disabled";
      system_info.distro = "nixos";

      cloud_init_modules = [
        "migrator"
        "seed_random"
        "write-files"
        "update_hostname"
        "resolv_conf"
        "ca-certs"
        "rsyslog"
        "users-groups"
      ];

      # Remove failing final modules
      cloud_final_modules = [
        "rightscale_userdata"
        "keys-to-console"
        "phone-home"
        "final-message"
        "power-state-change"
      ];
    };
  };
}
