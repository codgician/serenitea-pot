{ lib, pkgs, ... }:
{
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "sr_mod"
      ];
      kernelModules = [ ];
    };

    supportedFilesystems = [ "vfat" ];
    kernelModules = [ ];
    kernelParams = [ ];
    kernelPackages = pkgs.linuxPackages_6_18;
    extraModulePackages = [ ];
  };

  fileSystems."/persist".neededForBoot = true;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
