{ pkgs, ... }:
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
      kernelModules = [
        "tpm_tis"
      ];
    };

    kernelModules = [ "kvm-intel" ];

    plymouth = {
      enable = true;
      theme = "nixos-bgrt";
      themePackages = [ pkgs.nixos-bgrt-plymouth ];
    };

    zfs.extraPools = [ "dpool" ];
  };

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

  # USB WiFi adapter mode switching (CD-ROM -> WiFi)
  hardware.usb-modeswitch.enable = true;

  hardware.graphics.extraPackages = with pkgs; [ intel-vaapi-driver ];

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
  ];

  hardware.cpu.intel.updateMicrocode = true;
}
