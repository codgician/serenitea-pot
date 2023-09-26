{ config, lib, pkgs, ... }: {
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.extraModprobeConfig = "options i915 enable_guc=2";

  virtualisation.kvmgt.enable = true;

  nixpkgs.config.allowUnfree = true;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/fd7ac50f-2151-4d5b-b6ab-7845cae9bd16";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-16c2bc92-4078-42ea-a46a-da588fff863e".device = "/dev/disk/by-uuid/16c2bc92-4078-42ea-a46a-da588fff863e";

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/5E00-BA99";
      fsType = "vfat";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/c53da770-f4a7-4261-ac13-dd1d13270a9d"; }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}