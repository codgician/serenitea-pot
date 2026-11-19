{ pkgs, ... }:
{
  codgician = {
    services = {
      postfix.enable = true;

      # RAS hardware error monitoring (EDAC/DIMM ECC, PCIe AER, CPU MCE)
      rasdaemon.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence = {
        enable = true;
        wipeOnShutdown.zfs.enable = true;
      };
      secure-boot.enable = true;
    };

    users.codgi.enable = true;
  };

  services.vscode-server.enable = true;

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
    };

    home.stateVersion = "26.05";
  };

  # Use systemd-boot boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # Enable zram swap
  zramSwap.enable = true;

  # Use networkd
  networking.useNetworkd = true;

  system.stateVersion = "26.05";
}
