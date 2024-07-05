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
      ];
      kernelModules = [
        "tpm_crb"
        "tpm_tis"
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
      ];
    };

    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
      "hugepagesz=1G"
      "default_hugepagesz=2M"
    ];
  };

  # Specify nvme0n1p1 as the primary ESP partition
  boot.loader.efi.efiSysMountPoint = "/boot-nvme0n1";

  # Sync content to backup ESP partition on activation
  system.activationScripts.rsync-esp.text = ''
    if ! ${pkgs.util-linux}/bin/mountpoint -q /boot-nvme0n1; then
      echo -e "\033[0;33mWARNING: /boot-nvme0n1 not mounted, RAID-1 might have degraded.\033[0m"
    elif ! ${pkgs.util-linux}/bin/mountpoint -q /boot-nvme1n1; then
      echo -e "\033[0;33mWARNING: /boot-nvme1n1 not mounted, RAID-1 might have degraded.\033[0m"
    else
      echo "Syncing /boot-nvme0n1 to /boot-nvme1n1..."
      ${pkgs.rsync}/bin/rsync -a --delete /boot-nvme0n1/ /boot-nvme1n1/
    fi
  '';

  # The root partition decryption key encrypted with tpm
  # `echo $PLAINTEXT | sudo clevis encrypt tpm2 '{"pcr_bank":"sha384","pcr_ids":"7"}'`
  boot.initrd.clevis = {
    enable = true;
    devices."zroot".secretFile = ./zroot.jwe;
  };

  # Enable graphics
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [ virglrenderer ];
  };

  # Hardware-specific global packages
  environment.systemPackages = with pkgs; [ intel-gpu-tools ];

  # Enable zramSwap
  zramSwap.enable = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
