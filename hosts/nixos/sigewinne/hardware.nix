{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  kernelUpdater = pkgs.writeShellApplication {
    name = "update-initramfs";
    runtimeInputs = [ pkgs.coreutils ];
    text = "dd if=${config.mobile.outputs.depthcharge.kpart} of=/dev/mmcblk0p1";
  };
in
{
  imports = [
    (import "${inputs.mobile-nixos}/lib/configuration.nix" { device = "lenovo-krane"; })
  ];

  # Required for autorotate
  hardware.sensor.iio.enable = lib.mkDefault true;

  # Custom kernel
  mobile = {
    boot.stage-1 = {
      enable = true;
      kernel.package = lib.mkForce (
        pkgs.callPackage ./kernel {
          inherit (pkgs.linuxPackages_6_6) kernel;
        }
      );
    };

    # Make panel landscape
    hardware.screen = lib.mkForce {
      width = 1920;
      height = 1200;
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/a7c93308-529e-4c3d-b856-c021c86f87f0";
      fsType = "ext4";
    };
  };

  # boot.initrd.luks.devices = {
  #   "LUKS-SIGEWINNE-ROOTFS" = {
  #     device = "/dev/disk/by-uuid/fcb89377-a96e-4a68-8c5f-8a25364432d4";
  #   };
  # };

  nix.settings.max-jobs = lib.mkDefault 4;

  # Script for updating initramfs
  environment.systemPackages = [ kernelUpdater ];

  # Update kernel on activation
  system.activationScripts.kernelUpdater = {
    supportsDryActivation = false;
    text = "${kernelUpdater}/bin/update-initramfs";
  };
}
