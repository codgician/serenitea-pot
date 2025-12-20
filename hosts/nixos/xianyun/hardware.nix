{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  inherit (config.networking) hostName;
  terraformConf =
    builtins.fromJSON
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.value;
  publicIpv6 = terraformConf.resource.cloudflare_dns_record."${hostName}-aaaa".content;
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

    # Force RA acceptance when forwarding is enabled
    kernel.sysctl."net.ipv6.conf.eth0.accept_ra" = "2";

    supportedFilesystems = [
      "vfat"
      "zfs"
    ];

    # The default /dev/disk/by-id is empty in Tencent CVM
    zfs.devNodes = "/dev/disk/by-path";
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  # Enable cloud-init
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig.Restart = "on-failure";

  # Manually configure ipv6 network on Tencent Cloud
  networking = {
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv6 = {
      addresses = [
        {
          address = publicIpv6;
          prefixLength = 128;
        }
      ];
      routes = [
        {
          address = "::";
          prefixLength = 0;
          via = "fe80::feee:ffff:feff:ffff";
          options.onlink = true;
        }
      ];
    };
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

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
