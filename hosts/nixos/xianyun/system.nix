{ lib, ... }:
{
  codgician = {
    services = {
      coturn = {
        enable = true;
        openFirewall = true;
        listening-ips = [
          "0.0.0.0"
          "::"
        ];
      };

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

      nixos-vscode-server.enable = true;

      sing-box = {
        enable = true;
        domain = "xianyun.${lib.codgician.zone}";
        users = [
          "codgi"
          "lxm75"
          "itscd"
        ];
        servers.hysteria2.enable = true;
        servers.shadowsocks = {
          enable = true;
          port = 8444;
        };
      };

      wireguard = {
        enable = true;
        openFirewall = true;
        interfaces.wg0 = {
          host = "xianyun";
          peers = [
            "furina"
            "lumidouce"
            "lumine"
            "qiaoying"
          ];
          allowedIPsAsRoutes = true;
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence = {
        enable = true;
        wipeOnShutdown.zfs = {
          enable = true;
          datasets = [ "zroot/root" ];
        };
      };
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
    };
  };

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
