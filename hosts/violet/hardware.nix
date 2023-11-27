{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (import ./disks.nix { })
  ];

  boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    open = true;
    nvidiaSettings = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
