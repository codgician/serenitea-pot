{ lib, pkgs, ... }:
{
  codgician = {
    secrets.files.nats-controller-seed.owner = "codgi";

    services = {
      fcitx5.enable = true;
      plasma = {
        enable = true;
        wallpaper =
          (pkgs.fetchurl {
            url = "https://media.githubusercontent.com/media/codgician/assets/refs/heads/main/images/wallpapers/genshin-luna-viii.jpg";
            sha256 = "sha256-VjoCRP8AENaUlItKCn2751GY+WtF0ncwcBWYuJHmCWE=";
          }).outPath;
      };

      sing-box = {
        enable = true;
        clients.ss-lumidouce = {
          enable = true;
          bindInterface = "eno1-guest";
        };
        tun = {
          enable = true;
          routedRanges = [
            "192.168.0.0/16"
            "fd00:c0d9:1c00::/48"
          ];
        };
      };

      # Samba share for /code (dev-optimized for Windows 11 client over Thunderbolt)
      samba = {
        enable = true;
        users = [ "codgi" ];
        shares = {
          code = {
            path = "/code";
            browsable = "yes";
            writeable = "yes";
            "valid users" = "codgi";
            "read only" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";

            # Case sensitivity: critical for git/IDE performance
            # Prevents expensive directory scans for case-insensitive lookups
            "case sensitive" = "yes";
            "default case" = "lower";
            "preserve case" = "yes";
            "short preserve case" = "yes";

            # Oplocks: allow Windows to cache files locally
            "oplocks" = "yes";
            "level2 oplocks" = "yes";
            "kernel oplocks" = "yes";

            # Locking: relax for IDE/Git patterns
            "strict locking" = "no";
            "posix locking" = "no";

            # Symlinks: common in codebases
            "follow symlinks" = "yes";
            "wide links" = "yes";
            "allow insecure wide links" = "yes";

            # Veto noise files
            "veto files" = "/.DS_Store/Thumbs.db/desktop.ini/";
            "delete veto files" = "yes";
          };
        };
      };

      # RAS hardware error monitoring (EDAC/DIMM ECC, PCIe AER, CPU MCE)
      rasdaemon.enable = true;

      # Microsoft Intune enrollment (device compliance, identity broker,
      # Defender for Endpoint, VPN)
      intune = {
        enable = true;
        printer.user = "shijiazhang";
      };
    };

    system = {
      auto-upgrade.enable = true;
      common.audio.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    virtualization.podman.enable = true;

    users.codgi = {
      enable = true;
      passwordSecret = "codgi-password";
    };
  };

  services.vscode-server.enable = true;

  home-manager.users.codgi =
    let
      # Native Wayland rendering can interleave pointer-surface commits with NVIDIA
      # explicit-sync commits. Use XWayland to avoid syncobj protocol crashes.
      looking-glass-client-nvhack = pkgs.looking-glass-client.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
        postFixup = (old.postFixup or "") + ''
          wrapProgram $out/bin/looking-glass-client \
            --unset WAYLAND_DISPLAY \
            --add-flags app:renderer=OpenGL
        '';
      });
    in
    {
      codgician.codgi = {
        bilibili = {
          enable = true;
          gpuAcceleration = "nvidia";
        };
        codex.enable = true;
        claude-code.enable = true;
        dev = {
          dotnet.enable = true;
          nix.enable = true;
        };
        mcp.enable = true;
        oh-my-pi = {
          enable = true;
          defaultProfile = "github-copilot";
        };
        github-copilot-cli.enable = true;
        git.directoryIdentities = {
          "/code/" = "work";
          "~/GitHub/" = "personal";
        };
        herdr = {
          enable = true;
          desktop.enable = true;
          ovis.enable = true;
        };

        plasma = {
          scale = 1.5;
          krdp.enable = true;
          launchers = [
            "applications:org.kde.dolphin.desktop"
            "applications:microsoft-edge.desktop"
            "applications:org.kde.konsole.desktop"
            "applications:code.desktop"
            "applications:teams-for-linux.desktop"
          ];
        };

        easyeffects.enable = true;
        teams-for-linux.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        vscode.enable = true;
      };

      # Set Microsoft Edge as default browser
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "microsoft-edge.desktop";
          "x-scheme-handler/http" = "microsoft-edge.desktop";
          "x-scheme-handler/https" = "microsoft-edge.desktop";
          "x-scheme-handler/about" = "microsoft-edge.desktop";
          "x-scheme-handler/unknown" = "microsoft-edge.desktop";
        };
      };
      xdg.configFile."mimeapps.list".force = true;

      home.stateVersion = "26.05";

      home.packages =
        with pkgs;
        [
          # Microsoft Intune (compliance) tooling
          microsoft-edge
          azure-cli
          yubikey-manager
          yubico-piv-tool
          unstable.cider-2
          unstable.splayer-next
          virt-manager
          looking-glass-client-nvhack
          telegram-desktop
          nextcloud-talk-desktop
          element-desktop
          discord
          voxtype-onnx
          moonlight-qt
          thunderbird-bin
          firefox-bin
        ]
        ++ (with pkgs.nur.repos.codgician; [
          nanokvm-usb
        ]);
    };

  # Enable Network Manager (leave thunderbolt0 to systemd-networkd)
  networking.networkmanager = {
    enable = true;
    unmanaged = [ "thunderbolt0" ];

    ensureProfiles.profiles = {
      eno1 = {
        connection = {
          id = "eno1";
          type = "ethernet";
          interface-name = "eno1";
          autoconnect = true;
        };

        ipv4 = {
          method = "auto";
          route-metric = 100;
        };

        ipv6 = {
          method = "auto";
          route-metric = 100;
          addr-gen-mode = "stable-privacy";
        };
      };

      eno1-guest = {
        connection = {
          id = "eno1-guest";
          type = "macvlan";
          interface-name = "eno1-guest";
          autoconnect = true;
        };

        ethernet.cloned-mac-address = "b0:7b:25:23:66:63";

        macvlan = {
          parent = "eno1";
          mode = 2; # Bridge mode
        };

        ipv4 = {
          method = "auto";
          route-metric = 600;
          ignore-auto-dns = true;
        };

        ipv6 = {
          method = "auto";
          route-metric = 600;
          ignore-auto-dns = true;
        };
      };

    };
  };
  networking.hostId = "357a80da";

  # DNS for sing-box TUN (matchConfig supplied by the sing-box module)
  systemd.network = {
    wait-online.enable = false;
    networks."50-sing-box-tun" = {
      dns = [ "192.168.0.1" ];
      domains = [
        "~cdu"
        "~lan"
        "~${lib.codgician.inventory.zone}"
      ];
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "nixos-bgrt";
    themePackages = [ pkgs.nixos-bgrt-plymouth ];
  };

  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  # Already set by the common module; the second definition repeats both
  # entries in nix.conf.
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Global packages
  environment.systemPackages = with pkgs; [
    google-chrome
  ];

  zramSwap.enable = true;

  # Disable auto-suspend: NVIDIA s2idle resume deadlocks the host.
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Increase inotify limits for IDEs (VS Code, JetBrains) over SMB
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  # Keyfile directory for secondary LUKS disk
  systemd.tmpfiles.rules = [
    "d /persist/keys 0700 root root -"
  ];

  # Enable nix-ld
  programs.nix-ld.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
