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
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [
        "tpm_crb"
        "tpm_tis"
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
      ];
    };

    kernelPackages = pkgs.linuxPackages_6_12;
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "hugepagesz=1G"
      "default_hugepagesz=2M"
      "pcie_aspm=off"
      "isolcpus=2-5"
      "nohz_full=2-5"
    ];
  };

  # Connected to UPS
  codgician.power.ups.devices.br1500g.sku = "br1500g";

  # Specify boot-0 as the primary ESP partition
  boot.loader.efi.efiSysMountPoint = "/boot-0";

  # Mount efi partitions at boot
  fileSystems = {
    "/boot-0".neededForBoot = true;
    "/boot-1".neededForBoot = true;
  };

  # Bind first 3 ethernet cards to vfio for passthrough
  boot.initrd.preDeviceCommands = ''
    devs="0000:01:00.0 0000:02:00.0 0000:03:00.0"
    for dev in $devs; do 
      echo "vfio-pci" > /sys/bus/pci/devices/$dev/driver_override 
    done
    modprobe -i vfio-pci
  '';

  # Sync content to backup ESP partition on activation
  system.activationScripts.rsync-esp.text = ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /boot-0; then
      echo -e "\033[0;33mWARNING: /boot-0 not mounted, RAID-1 might have degraded.\033[0m"
    elif ! ${pkgs.util-linux}/bin/mountpoint -q /boot-1; then
      echo -e "\033[0;33mWARNING: /boot-1 not mounted, RAID-1 might have degraded.\033[0m"
    else
      echo "Syncing /boot-0 to /boot-1..."
      ${lib.getExe pkgs.rsync} -a --delete /boot-0/ /boot-1/
    fi
  '';

  # The root partition decryption key encrypted with tpm
  # `echo $PLAINTEXT | sudo clevis encrypt tpm2 '{"pcr_bank":"sha384","pcr_ids":"7"}'`
  boot.initrd.clevis = {
    enable = true;
    devices."zroot".secretFile = ./zroot.jwe;
  };

  # Enable graphics
  hardware.graphics.enable = true;

  # Hardware-specific global packages
  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    virglrenderer
    lm_sensors
    clevis
    jose
    tpm2-tools
  ];

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
