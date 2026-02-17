{
  config,
  lib,
  pkgs,
  ...
}:
let
  ethernetConfig = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
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
        "e1000e"
      ];
      kernelModules = [ ];

      # SSH in initrd for emergency remote unlock if Tang fails
      # Usage: ssh -p 2222 root@zibai "zfs load-key zroot && exit"
      network = {
        enable = true;
        ssh.enable = true;
      };

      systemd.network = {
        enable = true;
        networks."10-ethernet" = ethernetConfig;
        wait-online = {
          enable = true;
          timeout = 0;
        };
      };

      # Tang-based auto-unlock for zroot
      # Generate JWE: nix run .#mkjwe -- tang --url http://192.168.6.1:9090
      clevis = {
        enable = true;
        useTang = true;
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
  systemd.network.networks."10-ethernet" = ethernetConfig;

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    lm_sensors
    clevis
    jose
  ];

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
