{ config, lib, pkgs, ... }: {
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/06366069-9e8d-4f11-b01c-01444c9034c4";
      fsType = "ext4";
    };
  };

  boot.initrd.luks.devices = {
    "LUKS-CHARLOTTE-ROOTFS" = {
      device = "/dev/disk/by-uuid/d38d7e73-fb30-4dbf-be5b-903bfd2c239e";
    };
  };

  # Make panel landscape
  mobile.hardware.screen = lib.mkForce {
    width = 1920;
    height = 1200;
  };

  nix.settings.max-jobs = lib.mkDefault 4;
}
