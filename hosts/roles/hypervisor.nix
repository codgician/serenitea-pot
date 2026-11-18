{ lib, pkgs, ... }:
{
  codgician = {
    power.ups.devices.br1500g = { };
    services.postfix.enable = true;
  };

  services.fwupd.enable = true;

  boot.swraid = {
    enable = true;
    mdadmConf = "MAILADDR codgi";
  };

  # Both system disks carry an ESP. The boot loader is installed to /boot-0
  # and every activation copies it to /boot-1.
  boot.loader.efi.efiSysMountPoint = "/boot-0";

  fileSystems = {
    "/boot-0".neededForBoot = true;
    "/boot-1".neededForBoot = true;
  };

  system.activationScripts.rsync-esp = {
    deps = [ "udevd" ];
    text = ''
      if ! ${pkgs.util-linux}/bin/mountpoint -q /boot-0; then
        echo -e "\033[0;33mWARNING: /boot-0 not mounted, RAID-1 might have degraded.\033[0m"
      elif ! ${pkgs.util-linux}/bin/mountpoint -q /boot-1; then
        echo -e "\033[0;33mWARNING: /boot-1 not mounted, RAID-1 might have degraded.\033[0m"
      else
        echo "Syncing /boot-0 to /boot-1..."
        ${lib.getExe pkgs.rsync} -a --delete /boot-0/ /boot-1/
      fi
    '';
  };
}
