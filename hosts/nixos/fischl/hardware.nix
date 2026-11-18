{
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "iommu.passthrough=0"
      "intel_iommu=on"
      "hugepagesz=1G"
      "default_hugepagesz=1G"
      "hugepages=6"
      "pcie_aspm=off"
      "pcie_port_pm=off"
    ];
  };

  # Connected to UPS
  codgician.power.ups.devices.br1500g = { };

  # Specify boot-0 as the primary ESP partition
  boot.loader.efi.efiSysMountPoint = "/boot-0";

  # Mount efi partitions at boot
  fileSystems = {
    "/boot-0".neededForBoot = true;
    "/boot-1".neededForBoot = true;
  };

  # Sync content to backup ESP partition on activation
  system.activationScripts.rsync-esp = {
    deps = [ "udevd" ];
    text = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q /boot-0; then
        echo -e "\033[0;33mWARNING: /boot-0 not mounted, RAID-1 might have degraded.\033[0m"
      elif ! ${pkgs.util-linux}/bin/mountpoint -q /boot-1; then
        echo -e "\033[0;33mWARNING: /boot-1 not mounted, RAID-1 might have degraded.\033[0m"
      else
        echo "Syncing /boot-0 to /boot-1..."
        ${lib.getExe pkgs.rsync} -a --delete /boot-0/ /boot-1/
      fi
    '';
  };

  # Global packages
  environment.systemPackages = with pkgs; [
    lm_sensors
    smartmontools
    pciutils
    nvme-cli
    usbutils
    powertop
    nvtopPackages.intel
  ];

  hardware.cpu.intel.updateMicrocode = true;

  services.thermald.enable = true;

  security.tpm2.enable = false;
}
