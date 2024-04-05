{ config, lib, pkgs, inputs, ... }: {
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  # Custom kernel
  mobile = {
    boot.stage-1 = {
      networking.enable = true;
      networking.IP = "192.168.0.245";
      ssh.enable = true;
      enable = true;
      kernel.package = lib.mkForce (pkgs.callPackage ./kernel { });
    };

    # Make panel landscape
    hardware.screen = lib.mkForce {
      width = 1920;
      height = 1200;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/dd5bec0f-05ce-4f5f-bf0c-7f3767f07778";
      fsType = "ext4";
    };
  };

  # boot.initrd.luks.devices = {
  #   "LUKS-CHARLOTTE-ROOTFS" = {
  #     device = "/dev/disk/by-uuid/70f3f785-54fd-47fd-8551-0aa8742d5b40";
  #   };
  # };

  nix.settings.max-jobs = lib.mkDefault 4;
}
