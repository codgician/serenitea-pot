{ pkgs, ... }:
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
