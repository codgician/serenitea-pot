{
  config,
  lib,
  pkgs,
  ...
}:
{
  codgician = {
    system = {
      auto-upgrade.enable = true;
      impermanence.enable = lib.mkDefault true;
    };

    users.codgi.hashedPasswordSecret = "codgi-hashed-password";
  };

  services.vscode-server.enable = true;

  # Pinned together: the ZFS release has to support the kernel.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_6_18;
  boot.zfs.package = pkgs.zfs_2_4;

  # Impermanence binds from /persist in the initrd.
  fileSystems = lib.mkIf (config.codgician.system.impermanence.enable && !config.boot.isContainer) {
    "/persist".neededForBoot = true;
  };

  networking.useNetworkd = lib.mkDefault true;

  zramSwap.enable = lib.mkDefault true;
}
