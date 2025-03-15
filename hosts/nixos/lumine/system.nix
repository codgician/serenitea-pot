{ lib, pkgs, ... }:
{

  # My settings
  codgician = {
    services = {
      grafana = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "gardemek.codgician.me" ];
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
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
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

      home.stateVersion = "24.11";
      home.packages = with pkgs; [
        httplz
        screen
      ];
    };

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ZFS configurations
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
    expandOnBoot = "all";
    trim.enable = true;
  };

  # ZFS boot configs
  boot.supportedFilesystems = [ "zfs" ];
  fileSystems."/nix/persist".neededForBoot = true;
  networking.hostId = "2b4cf168";

  # Enable zram swap
  zramSwap.enable = true;

  # Use networkd
  networking.useNetworkd = true;

  # Firewall
  networking.firewall.enable = true;

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
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
  system.stateVersion = "24.11"; # Did you read the comment?
}
