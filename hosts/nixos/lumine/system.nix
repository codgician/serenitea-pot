{ lib, ... }:
{
  codgician = {
    services = {
      fcitx5.enable = true;
      litellm = {
        enable = true;
        adminUi = {
          enable = true;
          authelia.enable = true;
        };
      };
      nixos-vscode-server.enable = true;
      ovis-relay.enable = true;
      postgresql.zfsOptimizations = true;
      sing-box = {
        enable = true;
        domain = "lumine.${lib.codgician.zone}";
        users = [ "codgi" ];
        servers.hysteria2.enable = true;
      };
      wireguard = {
        enable = true;
        openFirewall = true;
        allowedIPsAsRoutes = true;
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence = {
        enable = true;
        wipeOnShutdown.zfs.enable = true;
      };
    };

    users.codgi.enable = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      github-copilot-cli.enable = true;
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

  networking.hostId = "2b4cf168";

  zramSwap.enable = true;

  networking.useNetworkd = true;

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq_pie";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Select internationalisation properties.
  i18n = {
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  system.stateVersion = "26.05";
}
