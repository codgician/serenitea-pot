{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/b2dccf20-c978-4335-8591-729cfc8d7da3";
      fsType = "ext4";
    };
  };

  boot.initrd.luks.devices = {
    "LUKS-NOIR-ROOTFS" = {
      device = "/dev/disk/by-uuid/ee50e9c7-b47d-4202-bed2-d7b275b40e40";
    };
  };

  # Make panel landscape
  mobile.hardware.screen = lib.mkForce {
    width = 1920;
    height = 1200;
  };

  nix.settings.max-jobs = lib.mkDefault 4;
}
