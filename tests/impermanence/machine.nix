# VM configuration for impermanence wipe-on-boot test
{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # Set root password for VM test (common module won't lock root when this is set)
  users.users.root.initialPassword = "root";
  virtualisation = {
    emptyDiskImages = [ 4096 ];
    useBootLoader = true;
    useEFIBoot = true;
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.timeout = 0;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = [ "zfs" ];
    zfs.devNodes = "/dev/disk/by-uuid";
    initrd.systemd.enable = true;
  };

  networking.hostId = "deadbeef";

  environment.systemPackages = [ pkgs.parted ];

  # Minimal impermanence config for testing
  codgician.system.impermanence = {
    enable = true;
    wipeOnBoot.zfs = {
      enable = true;
      dataset = "testpool/persist";
    };
  };

  # Define the persist filesystem
  fileSystems."/persist" = {
    device = "testpool/persist";
    fsType = "zfs";
    neededForBoot = true;
  };
}
