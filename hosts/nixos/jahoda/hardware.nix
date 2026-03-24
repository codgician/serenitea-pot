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
        "nvme"
        "thunderbolt"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [
        "vfio"
        "vfio_pci"
        "vfio_iommu_type1"
      ];

      systemd.services.bind-vfio = {
        description = "Bind first GPU to vfio for passthrough";
        wantedBy = [ "initrd.target" ];
        script = ''
          devs="0000:4f:00.0 0000:4f:00.1"
          for dev in $devs; do 
            echo "vfio-pci" > /sys/bus/pci/devices/$dev/driver_override 
          done
          modprobe -i vfio-pci
        '';
        serviceConfig.Type = "oneshot";
      };
    };

    kernelModules = [
      "kvm-intel"
      "kvmfr"
    ];
    kernelParams = [
      "iommu.passthrough=0"
      "intel_iommu=on"
      "hugepagesz=1G"
      "default_hugepagesz=1G"
      "hugepages=24"
    ];

    extraModulePackages = with config.boot.kernelPackages; [ kvmfr ];
    extraModprobeConfig = ''
      options kvmfr static_size_mb=512
    '';

    kernelPackages = pkgs.linuxPackages_6_18;
    zfs.package = pkgs.zfs_2_4;
    supportedFilesystems = [ "vfat" ];
  };

  # KVMFR device permissions for Looking Glass client
  # Note: OWNER="codgi" doesn't work - systemd-udevd rejects non-system users (UID >= 1000)
  # Use TAG+="uaccess" to grant logged-in user access via ACL instead
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
  '';

  # Stage-2 unlock for code disk using NixOS encrypted device mechanism
  fileSystems."/code".encrypted = {
    enable = true;
    blkDev = "/dev/disk/by-partlabel/disk-code-code";
    label = "crypted-code";
    keyFile = "/sysroot/persist/keys/crypted-code.key";
  };

  # Enable OpenGL and VA-API for NVIDIA
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
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
    nvtopPackages.nvidia
  ];

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # TPM
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  # Thunderbolt Ethernet - static IP for direct connection
  systemd.network.enable = true;

  systemd.network.networks."10-thunderbolt" = {
    matchConfig.Name = "thunderbolt0";
    address = [ "172.16.0.1/24" ];
    networkConfig.ConfigureWithoutCarrier = true;
    linkConfig.MTUBytes = "62000";
  };

  # Intel CPU microcode
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

  hardware.enableRedistributableFirmware = true;

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
