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
        "mlx5_core"
      ];
    };

    kernelPackages = pkgs.linuxPackages_6_12;
    kernelModules = [
      "kvm-amd"
      "ast"
    ];
    kernelParams = [
      "video=astdrmfb"
      "amd_pstate=active"
      "amd_iommu=on"
      "iommu=pt"
      "hugepagesz=1G"
      "default_hugepagesz=2M"
      "kvm_amd.npt=1"
      "kvm_amd.avic=1"
      "kvm_amd.force_avic=1"
      "iomem=relaxed"
    ];

    extraModprobeConfig = ''
      options vfio-pci ids=10de:1cb6,10de:0fb9,10de:2882,10de:22be
      options kvm ignore_msrs=1
      options kvm report_ignored_msrs=0
    '';

    supportedFilesystems = [
      "vfat"
      "zfs"
    ];

    zfs = {
      forceImportAll = true;
      requestEncryptionCredentials = true;
    };

    postBootCommands = ''
      ${lib.getExe pkgs.zfs} load-key -a
      ${lib.getExe pkgs.zfs} mount -a
    '';
  };

  # Selfhost mlnx-ofed-nixos
  hardware.mlnx-ofed = {
    enable = true;
    fwctl.enable = true;
    kernel-mft.enable = true;
    nfsrdma.enable = true;
    nvme.enable = true;
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
      ${lib.getExe pkgs.rsync} -a --delete /boot-0/ /boot-1/
    fi
  '';

  # The root partition decryption key encrypted with tpm
  # `echo $PLAINTEXT | sudo clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"1,7,12,14"}'`
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

  # Enable OpenGL
  hardware.graphics.enable = true;

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # CUDA support for nixpkgs
  nixpkgs.config.cudaSupport = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    gsp.enable = true;
    nvidiaPersistenced = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  # Limit TDP and powersave for nvidia card
  systemd.services = {
    nvidia-gpu-config = {
      description = "Configure NVIDIA GPU";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = [
          "${pkgs.coreutils}/bin/echo 'Limiting NVIDIA GPU TDP to 350W...'"
          "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pl 350"
        ];
        Type = "oneshot";
      };
    };
  };

  # Start ollama after configuring GPU
  # systemd.services.ollama.after = [ "nvidia-gpu-config.service" ];

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  # Connected to UPS
  codgician.power.ups.devices.br1500g = {
    sku = "br1500g";
    batteryLow = 20;
  };

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement = {
    cpuFreqGovernor = "powersave";
    powerUpCommands = lib.getExe (
      pkgs.writeShellApplication {
        name = "amd-set-energy-performance-preference";
        text = ''
          for cpu_path in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; 
            do echo "balance_performance" > "$cpu_path"; 
          done
        '';
      }
    );
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
