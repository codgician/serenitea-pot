{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  boot = {
    initrd = {
      availableKernelModules = [ ];
      kernelModules = [ ];
    };

    supportedFilesystems = [ "vfat" ];
    kernelModules = [ ];
    kernelParams = [
      "iommu.passthrough=1"
      # CIX P1 firmware leaves clocks lacking explicit Linux owners; without
      # this the common clock framework gates them off during bring-up.
      "clk_ignore_unused"
    ];
    kernelPackages = pkgs.linuxPackages_6_18;
    kernelPatches = import ./kernel.nix { inherit inputs lib; };
    zfs.package = pkgs.zfs_2_4;
    extraModulePackages = [ ];
  };

  # Enable OpenGL
  hardware.graphics.enable = true;

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    gsp.enable = true;
    nvidiaPersistenced = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
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

  # tpm2# TPM
  security.tpm2 = {
    enable = true;
    #abrmd.enable = true;
    pkcs11.enable = true;
  };

  hardware.enableRedistributableFirmware = true;

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
