{ pkgs, ... }:
{
  codgician = {
    services.postfix.enable = true;
    system.common.inChina = true;
  };

  # Allow RAID-1 esp boot
  boot.swraid = {
    enable = true;
    mdadmConf = "MAILADDR codgi";
  };

  # Customize zfs auto snapshot cadence
  services.zfs.autoSnapshot = {
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 0;
    monthly = 0;
    flags = "-k -p --utc";
  };

  networking.hostId = "4b6c6565";

  # Watchdog
  systemd.settings.Manager = {
    WatchdogDevice = "/dev/watchdog0";
    RuntimeWatchdogSec = "30";
    RebootWatchdogSec = "600";
  };

  # Firmware updates
  services.fwupd.enable = true;

  # Global packages
  environment.systemPackages = with pkgs; [
    libhugetlbfs
  ];

  system.stateVersion = "26.05";
}
