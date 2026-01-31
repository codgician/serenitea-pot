{ lib, pkgs, ... }:
{

  # My settings
  codgician = {
    services = {
      litellm = {
        enable = true;
        backend = "container";
        imageTag = "main-stable";
        adminUi = {
          enable = true;
          authelia.enable = true;
        };
        reverseProxy = {
          enable = true;
          domains = [ "dendro.codgician.me" ];
          favicon =
            (pkgs.fetchurl {
              url = "https://media.githubusercontent.com/media/codgician/assets/f541d8f18215690ed7b7bbc3b97aa54c6ef2f51e/images/dendro/logo.png";
              sha256 = "sha256-XSikOX3CM4VvwzWkRsETYBLha2VgUHh5m/uxTzm2UQI=";
            }).outPath;
        };
      };

      postgresql.zfsOptimizations = true;
      nixos-vscode-server.enable = true;
      wireguard = {
        enable = true;
        openFirewall = true;
        interfaces.wg0 = {
          host = "lumine";
          peers = [
            "furina"
            "lumidouce"
            "xianyun"
          ];
          allowedIPsAsRoutes = true;
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        screen
        tmux
      ];
    };

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Customize zfs auto snapshot cadence
  services.zfs.autoSnapshot = {
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 0;
    monthly = 0;
    flags = "-k -p --utc";
  };

  networking.hostId = "2b4cf168";

  # Enable zram swap
  zramSwap.enable = true;

  # Use networkd
  networking.useNetworkd = true;

  # Firewall
  networking.firewall.enable = true;

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq_pie";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Enable forwarding for WireGuard
    "net.ipv4.conf.all.forwarding" = "1";
    "net.ipv4.conf.all.proxy_arp" = "1";
    "net.ipv6.conf.all.forwarding" = "1";
    "net.ipv6.conf.all.proxy_ndp" = "1";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
