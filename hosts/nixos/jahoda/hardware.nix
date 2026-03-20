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
    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = [ ];
  };

  # Enable OpenGL
  hardware.graphics.enable = true;

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

  # Intel CPU microcode
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

  hardware.enableRedistributableFirmware = true;

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
