{
  config,
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
    kernelParams = [ ];
    kernelPackages = pkgs.linuxPackages_6_18;
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

  # tpm2# TPM
  security.tpm2 = {
    enable = true;
    #abrmd.enable = true;
    pkcs11.enable = true;
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
