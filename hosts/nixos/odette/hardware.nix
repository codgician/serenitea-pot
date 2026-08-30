{ lib, pkgs, ... }:
let
  pipewireWithChromebookUcm = pkgs.pipewire.override {
    alsa-lib = pkgs.alsa-lib.override {
      alsa-ucm-conf = pkgs.alsa-ucm-conf-chromebook;
    };
  };
in

{
  # HP Elite Dragonfly Chromebook with an Alder Lake-U i7-1265U.
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [ "intel_lpss_pci" ];
    };

    kernelModules = [ "kvm-intel" ];
    kernelPackages = pkgs.linuxPackages_6_18;
    zfs.package = pkgs.zfs_2_4;
    supportedFilesystems = [ "vfat" ];
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  hardware.bluetooth.enable = true;

  services.pipewire = {
    package = pipewireWithChromebookUcm;

    wireplumber = {
      package = pkgs.wireplumber.override {
        pipewire = pipewireWithChromebookUcm;
      };

      extraConfig."51-increase-headroom" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "~alsa_output.*"; } ];
            actions.update-props."api.alsa.headroom" = 2048;
          }
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    smartmontools
    pciutils
    nvme-cli
    usbutils
    powertop
    nvtopPackages.intel
  ];

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
  };

  powerManagement.cpuFreqGovernor = "powersave";

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
