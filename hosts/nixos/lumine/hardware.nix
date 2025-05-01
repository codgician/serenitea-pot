{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/azure-common.nix") ];

  # ZFS boot configs
  boot.supportedFilesystems = [
    "vfat"
    "zfs"
  ];
  fileSystems."/persist".neededForBoot = true;

  # Enable Accelerated Networking
  virtualisation.azure.acceleratedNetworking = true;

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable nix-ld
  programs.nix-ld.enable = true;
}
