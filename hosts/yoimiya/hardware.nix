{ config, lib, pkgs, ... }: {
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "virtio_pci"
        "virtio_scsi"
      ];
      kernelModules = [
        "tpm_crb"
        "tpm_tis"
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
        "mlx5_core"
      ];
    };

    kernelModules = [ "kvm-amd" "ast" ];
    kernelParams = [
      "video=astdrmfb"
      "amd_pstate=active"
      "amd_iommu=on"
      "iommu=pt"
      "hugepagesz=1G"
      "default_hugepagesz=2M"
      "kvm_amd.sev=1"
      "kvm_amd.avic=1"
      "kvm_amd.force_avic=1"
    ];

    extraModprobeConfig = ''
      blacklist nvidiafb
      options vfio-pci ids=10de:2204,10de:1aef,10de:1cb6,10de:0fb9,10de:2882,10de:22be
      options kvm ignore_msrs=1
      options kvm report_ignored_msrs=0
    '';
  };

  # Specify boot-0 as the primary ESP partition
  boot.loader.efi.efiSysMountPoint = "/boot-0";

  # Mount efi partitions at boot
  fileSystems = {
    "/boot-0".neededForBoot = true;
    "/boot-1".neededForBoot = true;
  };

  # Sync content to backup ESP partition on activation
  system.activationScripts.rsync-esp.text = ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /boot-0; then
      echo -e "\033[0;33mWARNING: /boot-0 not mounted, RAID-1 might have degraded.\033[0m"
    elif ! ${pkgs.util-linux}/bin/mountpoint -q /boot-1; then
      echo -e "\033[0;33mWARNING: /boot-1 not mounted, RAID-1 might have degraded.\033[0m"
    else
      echo "Syncing /boot-0 to /boot-1..."
      ${pkgs.rsync}/bin/rsync -a --delete /boot-0/ /boot-1/
    fi
  '';

  # The root partition decryption key encrypted with tpm
  # `echo $PLAINTEXT | sudo clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"1,7,14"}'`
  # boot.initrd.clevis = {
  #   enable = true;
  #   devices."zroot".secretFile = ./zroot.jwe;
  # };

  # Hardware-specific global packages
  environment.systemPackages = with pkgs; [
    lm_sensors
    clevis
    jose
    tpm2-tools
  ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault {
    gcc.arch = "x86-64-v3";
    system = "x86_64-linux";
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement = {
    cpuFreqGovernor = "powersave";
    powerUpCommands = ''
      for cpu_path in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; 
        do echo "balance_performance" > "$cpu_path"; 
      done
    '';
  };
}
