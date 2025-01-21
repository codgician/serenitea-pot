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
  services.cloud-init.settings.system_info = {
    distro = "nixos";
    preserve_hostname = true;
    network.renderers = lib.optionals config.networking.useNetworkd [ "networkd" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
