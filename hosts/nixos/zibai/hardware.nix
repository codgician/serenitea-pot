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
    cpuFreqGovernor = "schedutil"; # No HWP support for Haswell
    powertop = {
      enable = true;
      # Disable runtime PM for Intel 8 Series xHCI (Lynx Point)
      # Workaround for USB 3.0 hotplug detection issue when no device connected at boot
      postStart = ''
        for dev in /sys/bus/pci/devices/*; do
          if [ "$(cat "$dev/vendor" 2>/dev/null)" = "0x8086" ] && \
             [ "$(cat "$dev/device" 2>/dev/null)" = "0x8c31" ]; then
            echo on > "$dev/power/control"
          fi
        done
      '';
    };
  };

  fileSystems."/persist".neededForBoot = true;

  # Boot loader - using systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use systemd-networkd for network management
  networking.useNetworkd = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-vaapi-driver ];
  };

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

  # TPM
  security.tpm2 = {
    enable = true;
    abrmd.enable = true;
    pkcs11.enable = true;
  };

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
