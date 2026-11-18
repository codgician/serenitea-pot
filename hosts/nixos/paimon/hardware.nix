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
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
        "ast"
      ];
    };

    kernelModules = [
      "kvm-amd"
    ];
    # nixpkgs leaves NET_TC_SKB_EXT off, which compiles TC flower offload
    # (MLX5_CLS_ACT) out of the inbox mlx5 driver, so OVS hw-offload never
    # reaches the eSwitch. Listing MLX5_CLS_ACT fails the build if it drops
    # out again. MLX5_SF adds scalable functions.
    kernelPackages = pkgs.unstable.linuxPackagesFor (
      pkgs.unstable.linux_6_18.override {
        structuredExtraConfig = with lib.kernel; {
          NET_TC_SKB_EXT = yes;
          MLX5_CLS_ACT = yes;
          MLX5_SF = yes;
        };
      }
    );

    kernelParams = [
      "video=VGA-1:1600x900@60"
      "fbcon=map:0"
      "vfio-pci.ids=10de:2783,10de:22bc,10de:25b8,10de:2291"
      "amd_pstate=active"
      "hugepagesz=1G"
      "default_hugepagesz=1G"
      "hugepages=16"
      "kvm_amd.npt=1"
      "kvm_amd.avic=1"
      "kvm_amd.force_avic=1"
      "iommu.passthrough=0"
      "amd_iommu=force_isolation"
      "amd_iommu_intr=vapic"
      "iomem=relaxed" # todo: remove after nvidia experiment is done
    ];

    extraModulePackages = with config.boot.kernelPackages; [ mstflint_access ];

    zfs.extraPools = [
      "fpool"
      "opool"
      "xpool"
    ];
  };

  # Hardware-specific global packages
  environment.systemPackages = with pkgs; [
    lm_sensors
    pciutils
    smartmontools
    nvme-cli
    usbutils
    powertop
    nvtopPackages.nvidia
    mstflint
  ];

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    gsp.enable = true;
    nvidiaPersistenced = true;
    open = true;
    nvidiaSettings = true;
    # Keep this selection in sync with hosts/nixos/nahida/hardware.nix.
    package = config.boot.kernelPackages.nvidiaPackages.new_feature;
  };

  # Only the host's modified 48GB RTX 4090 D; leave the VFIO GPUs untouched.
  # NUR supplies the module and matching firmware. The first test needs a
  # cold boot before NVIDIA binds the card.
  hardware.gpu-unlock = {
    enable = true;
    targets = [ "0000:81:00.0" ];
    rtx4090dExperimental = true;
  };

  # Same kernel and driver, without the experimental pre-driver transaction.
  specialisation.without-gpu-unlock.configuration.hardware.gpu-unlock.enable = lib.mkForce false;

  # Restore the 4090 D's missing P5/P3/P2 levels: GSP loads the board's own
  # VBIOS with those level bytes re-enabled, relocated by Vix Editor. NUR
  # supplies the module and the driver patch.
  hardware.nvidia-vbios-override = {
    enable = true;
    images."0000:81:00.0" = ./vbios.bin;
  };

  # Stock driver and VBIOS. That table only has P0 and P8, and the driver never
  # leaves P0 on its own, so the idle quirk returns here.
  specialisation.without-vbios-override.configuration = {
    hardware.nvidia-vbios-override.enable = lib.mkForce false;

    # Quirk: see nvidia-gpu-idle-quirk.py
    systemd.services.nvidia-gpu-idle-quirk = {
      description = "Drop idle NVIDIA GPU from P0 to P8";
      wantedBy = [ "multi-user.target" ];
      wants = [ "nvidia-gpu-config.service" ];
      after = [ "nvidia-gpu-config.service" ];
      serviceConfig = {
        ExecStart = lib.getExe (
          pkgs.writers.writePython3Bin "nvidia-gpu-idle-quirk" {
            libraries = [ pkgs.python3Packages.nvidia-ml-py ];
          } (builtins.readFile ./nvidia-gpu-idle-quirk.py)
        );
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
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

  # Enable use of nvidia card in containers
  hardware.nvidia-container-toolkit.enable = true;

  # Connected to UPS
  codgician.power.ups.devices.br1500g.batteryLow = 20;

  hardware.cpu.amd.updateMicrocode = true;

  powerManagement.powertop.enable = true;

  # Configure energy_performance_preference and lower scaling_min_freq floor.
  # The amd-pstate driver defaults scaling_min_freq to lowest_nonlinear_freq (1523 MHz),
  # but for idle power savings we want cores to drop all the way to cpuinfo_min_freq.
  systemd.services."amd-pstate-epp-init" = {
    description = "Configure power policy for AMD P-State EPP";
    wantedBy = [ "multi-user.target" ];
    after = [ "cpufreq.service" ];
    script = ''
      for policy_path in /sys/devices/system/cpu/cpufreq/policy*/; do
        min_freq=$(cat "$policy_path/cpuinfo_min_freq")
        echo "$min_freq" > "$policy_path/scaling_min_freq"
        echo "balance_performance" > "$policy_path/energy_performance_preference"
      done
    '';
    serviceConfig.Type = "oneshot";
  };
}
