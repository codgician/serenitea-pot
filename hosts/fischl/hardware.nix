{ config, lib, pkgs, ... }:

{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "tpm_crb" "tpm_tis" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Specify nvme0n1p1 as the primary ESP partition
  boot.loader.efi.efiSysMountPoint = "/boot-nvme0n1";

  # Sync content to backup ESP partition on activation
  system.activationScripts.rsync-esp.text = ''
    ${pkgs.rsync}/bin/rsync -a --delete /boot-nvme0n1/ /boot-nvme1n1/
  '';  

  # The root partition decryption key encrypted with tpm
  # `echo $PLAINTEXT | clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"1,7,14"}'`
  boot.initrd.clevis = {
    enable = true;
    devices."zroot".secretFile = ./zroot.jwe;
  };

  zramSwap.enable = true;

  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp3s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
