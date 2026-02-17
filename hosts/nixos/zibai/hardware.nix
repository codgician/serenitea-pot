{
  config,
  lib,
  pkgs,
  ...
}:
let
  eno1Config = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };
in
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
      ];
      kernelModules = [ ];

      # Network in initrd for Tang-based disk unlock (shares config with regular boot)
      systemd.network = {
        enable = true;
        networks."10-eno1" = eno1Config;
      };

      # Tang-based auto-unlock for zroot
      # Generate JWE: nix run .#mkjwe -- tang --url http://qiaoying.cdu:9090
      clevis = {
        enable = true;
        devices."zroot".secretFile = ./zroot.jwe;
      };
    };

    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];

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
  systemd.network.networks."10-eno1" = eno1Config;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
