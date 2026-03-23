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
        "thunderbolt"
      ];
      kernelModules = [ ];
    };

    supportedFilesystems = [ "vfat" ];
    kernelModules = [ ];
    kernelParams = [ ];
    kernelPackages = pkgs.linuxPackages_6_18;
    extraModulePackages = [ ];
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
