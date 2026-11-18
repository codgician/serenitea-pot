{ pkgs, ... }:
{
  codgician.system.common.inChina = true;

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

  # Global packages
  environment.systemPackages = with pkgs; [
    libhugetlbfs
  ];

  system.stateVersion = "26.05";
}
