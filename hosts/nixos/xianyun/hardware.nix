{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  inherit (config.networking) hostName;
  terraformConf = builtins.fromJSON outputs.packages.${pkgs.system}.terraform-config.value;
  publicIpv6 = terraformConf.resource.cloudflare_dns_record."${hostName}-aaaa".content;
in
{
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "xhci_pci"
    "virtio_blk"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  # Enable cloud-init
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig.Restart = "on-failure";

  # Manually configure ipv6 network on Tencent Cloud
  services.cloud-init.network.enable = false;
  networking.interfaces.eth0.ipv6 = {
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
      }
    ];
  };

  # Override distro in cloud-init
  services.cloud-init.settings = {
    preserve_hostname = true;
    system_info = {
      distro = "nixos";
      network.renderers = lib.optionals config.networking.useNetworkd [ "networkd" ];
    };

    # Remove failing final modules
    cloud_final_modules = [
      "rightscale_userdata"
      "keys-to-console"
      "phone-home"
      "final-message"
      "power-state-change"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
