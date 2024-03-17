{ config, lib, pkgs, ... }: {
  imports = [ (import ./disks.nix { }) ];

  boot.supportedFilesystems = [ "bcachefs" ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelPackages = pkgs.linuxPackages_6_7;
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  zramSwap.enable = true;
  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "prl-tools" ];
  hardware.parallels = {
    enable = true;
    autoMountShares = true;
  };
}
