{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd = {
      # The root partition decryption key encrypted with tpm
      # `nix run .#mkjwe`
      clevis = {
        enable = true;
        devices."zroot".secretFile = ./zroot.jwe;
      };

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

    kernelModules = [
      "kvm-amd"
      "ast"
    ];
    kernelPackages = pkgs.linuxPackages_6_12;
    kernelParams = [
      "video=astdrmfb"
      "amd_pstate=active"
      "hugepagesz=1G"
      "default_hugepagesz=1G"
      "hugepages=16"
      "kvm_amd.npt=1"
      "kvm_amd.avic=1"
      "kvm_amd.force_avic=1"
      "amd_iommu=on"
      "iommu=pt"
      "amd_iommu_intr=vapic"
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
      package = pkgs.zfs_unstable;
      extraPools = [
        "fpool"
        "opool"
        "xpool"
      ];
      forceImportAll = true;
      requestEncryptionCredentials = [ "zroot" ];
    };
  };

  # ZFS load keys
  systemd.services."zfs-mount".preStart = "${lib.getExe config.boot.zfs.package} load-key -a";

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
    "/persist".neededForBoot = true;
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

  # Limit nvidia GPU TDP
  systemd.services.nvidia-gpu-config = {
    description = "Configure NVIDIA GPU";
    wantedBy = [ "multi-user.target" ];
    path = [ config.hardware.nvidia.package.bin ];
    script = ''
      echo 'Limiting NVIDIA GPU TDP to 350W...'
      nvidia-smi -pl 350
      nvidia-smi -rmc
    '';
    serviceConfig.Type = "oneshot";
  };

  # Hack: quirk to force GPU into P8 on idle
  systemd.timers.nvidia-gpu-idle-quirk = {
    description = "NVIDIA GPU idle quirk timer";
    wants = [ "nvidia-gpu-idle-quirk.service" ];
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "10min";
      AccuracySec = "1min";
    };
  };
  systemd.services.nvidia-gpu-idle-quirk = {
    description = "NVIDIA GPU idle quirk";
    wants = [ "nvidia-gpu-config.service" ];
    after = [ "nvidia-gpu-config.service" ];
    path = [
      pkgs.gawk
      config.hardware.nvidia.package.bin
    ];
    script = ''
      perf_state=$(
        nvidia-smi -q -d PERFORMANCE \
          | awk -F: '/^\s*Performance State/ {
              gsub(/^[ \t]+|[ \t]+$/, "", $2)
              print $2
              exit
            }'
      )

      if [ "$perf_state" != "P0" ]; then
        echo "Performance State is $perf_state, skipping idle quirk."
        exit 0
      fi

      idle_status=$(
        nvidia-smi -q -d PERFORMANCE \
          | awk -F: '/^\s*Idle\s*:/ {
              gsub(/^[ \t]+|[ \t]+$/, "", $2)
              print $2
              exit
            }'
      )

      if [ "$idle_status" == "Active" ]; then
        echo "Idle is Active, running idle quirk..."
        nvidia-smi -lmc 405
        sleep 1
        nvidia-smi -rmc
      else
        echo "Idle is $idle_status, skipping idle quirk."
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  # Start ollama after configuring GPU
  systemd.services.ollama.after = [ "nvidia-gpu-config.service" ];

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  # Connected to UPS
  codgician.power.ups.devices.br1500g = {
    sku = "br1500g";
    batteryLow = 20;
  };

  networking.useDHCP = lib.mkDefault true;

  hardware.cpu.amd = {
    # sev.enable = true;
    # sevGuest.enable = true;
    updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  powerManagement = {
    cpuFreqGovernor = "powersave";
    powertop.enable = true;
  };

  # Configure energy_performance_preference
  systemd.services."amd-pstate-epp-init" = {
    description = "Configure power policy for AMD P-State EPP";
    wantedBy = [ "multi-user.target" ];
    after = [ "cpufreq.service" ];
    script = ''
      for cpu_path in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; 
        do echo "balance_power" > "$cpu_path"; 
      done
    '';
    serviceConfig.Type = "oneshot";
  };

  nix.settings.system-features = [ "gccarch-znver3" ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
