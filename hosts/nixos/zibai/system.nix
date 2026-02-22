{
  config,
  lib,
  ...
}:
{

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;

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
            "guest ok" = "no";
            "create mask" = "0640";
            "directory mask" = "0751";
          };
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence = {
        enable = true;
        path = "/persist";
      };
      secure-boot.enable = true;
      nix.useCnMirror = true;
    };

    users = with lib.codgician; {
      codgi = {
        enable = true;
        hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
        extraGroups = [ "wheel" ];
      };

      smb = {
        enable = true;
        hashedPasswordAgeFile = getAgeSecretPathFromName "smb-qiaoying-hashed-password";
        passwordAgeFile = getAgeSecretPathFromName "smb-qiaoying-password";
      };
    };
  };

  # Wireless configuration (wpa_supplicant)
  networking.wireless = {
    enable = true;
    secretsFile = config.age.secrets.wireless-env.path;
    networks."grassland".pskRaw = "ext:GRASSLAND_PASS";
    extraConfig = ''
      ap_scan=1
      autoscan=periodic:30
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
      dhcpV6Config.RouteMetric = 100;
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
      dhcpV6Config.RouteMetric = 600;
      linkConfig.RequiredForOnline = "no-carrier";
    };
  };
  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        opencode.enable = true;
        mcp.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
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

  # Firewall
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
