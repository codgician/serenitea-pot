{ config, ... }:
{
  codgician = {
    services = {
      samba = {
        enable = true;
        users = [ "smb" ];
        shares = {
          "share" = {
            path = "/dpool/share";
            browsable = "yes";
            writeable = "yes";
            "force user" = "smb";
            "valid users" = "smb";
            "read only" = "no";
            "create mask" = "0640";
            "directory mask" = "0751";
          };
        };
      };

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

    users = {
      codgi.enable = true;

      smb = {
        enable = true;
        hashedPasswordSecret = "smb-qiaoying-hashed-password";
        passwordSecret = "smb-qiaoying-password";
      };
    };
  };

  services.vscode-server.enable = true;

  # Wireless configuration (wpa_supplicant)
  networking.wireless = {
    enable = true;
    scanOnLowSignal = true;
    secretsFile = config.codgician.secrets.templates."wireless-env".path;
    networks."grassland" = {
      pskRaw = "ext:GRASSLAND_PASS";
    };
    extraConfig = ''
      ap_scan=1
      autoscan=periodic:10
      disable_scan_offload=1
    '';
  };

  # systemd-networkd configuration: prefer ethernet over wireless
  systemd.network.networks = {
    # Ethernet - lower metric = preferred
    "10-ethernet" = {
      matchConfig.Type = "ether";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
      };
      dhcpV4Config.RouteMetric = 100;
      ipv6AcceptRAConfig.RouteMetric = 100;
      linkConfig.RequiredForOnline = "no-carrier";
    };

    # Wireless (USB adapter) - higher metric = fallback
    "20-wireless" = {
      matchConfig.Type = "wlan";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        IgnoreCarrierLoss = "5s";
      };
      dhcpV4Config = {
        RouteMetric = 600;
        UseMTU = true;
      };
      ipv6AcceptRAConfig.RouteMetric = 600;
      linkConfig.RequiredForOnline = "no-carrier";
    };
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      oh-my-pi.enable = true;
      mcp.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";
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

  networking.hostId = "02821ba1";

  # Enable zram swap
  zramSwap.enable = true;

  # Always-on server: disable all sleep states
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Firewall
  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
