{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd.availableKernelModules = [
    "uhci_hcd"
    "ehci_pci"
    "ahci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  networking.useDHCP = lib.mkDefault true;

  # Enable QEMU guest agent
  services.qemuGuest.enable = true;

  # Enable cloud-init
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig.Restart = "on-failure";
  services.cloud-init.network.enable = true;

  # Override distro in cloud-init
  services.cloud-init.settings = {
    preserve_hostname = true;
    system_info = {
      distro = "nixos";
      network.renderers = lib.optionals config.networking.useNetworkd [ "networkd" ];
    };
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
