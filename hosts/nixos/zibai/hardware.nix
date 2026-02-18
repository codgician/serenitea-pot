{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "usbhid"
        "uas"
        "sd_mod"
        "e1000e"
      ];
      kernelModules = [ ];

      # TPM-based auto-unlock for zroot
      # Generate JWE: nix run .#mkjwe -- tpm > zroot.jwe
      clevis = {
        enable = true;
        devices."zroot".secretFile = ./zroot.jwe;
      };
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };

    zfs = {
      extraPools = [ "dpool" ];
      forceImportAll = true;
      requestEncryptionCredentials = [ "zroot" ];
    };
  };

  # ZFS load keys
  systemd.services."zfs-mount".preStart = "${lib.getExe config.boot.zfs.package} load-key -a";

  powerManagement = {
    cpuFreqGovernor = "powersave";
    powertop.enable = true;
  };

  fileSystems."/persist".neededForBoot = true;

  # Boot loader - using systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use systemd-networkd for network management
  networking.useNetworkd = true;

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    lm_sensors
    pciutils
    smartmontools
    nvme-cli
    usbutils
    ethtool
    sysstat
    powertop
    nvtopPackages.intel
    clevis
    jose
    tpm2-tools
  ];

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
