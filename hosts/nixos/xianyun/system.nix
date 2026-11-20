{ ... }:
{
  codgician = {
    services = {
      coturn.enable = true;

      nginx = {
        enable = true;
        openFirewall = true;
        landingPage = {
          domain = "codgi.cn";
          footer = ''
            Coming Soon...
            <footer>
              <a href="https://beian.miit.gov.cn/">蜀ICP备2026006850号</a>
            </footer>'';
        };
      };

      sing-box = {
        enable = true;
        users = [
          "codgi"
          "lxm75"
          "itscd"
        ];
        servers.hysteria2.enable = true;
        servers.shadowsocks.enable = true;
      };

      wireguard.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence = {
        enable = true;
        wipeOnShutdown.zfs.enable = true;
      };
    };

    users.codgi.enable = true;
  };

  services.vscode-server.enable = true;

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      git.enable = true;
      oh-my-pi.enable = true;
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

  networking.hostId = "f52ce96f";

  # Use grub bootloader
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    zfsSupport = true;
  };

  zramSwap.enable = true;

  networking.useNetworkd = true;

  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq_pie";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  system.stateVersion = "26.05";
}
