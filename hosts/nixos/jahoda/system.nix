{ lib, pkgs, ... }:
{
  codgician = {
    secrets.files.nats-controller-seed.owner = "codgi";

    services = {
      sing-box = {
        clients.ss-lumidouce.bindInterface = "eno1-guest";
        tun.routedRanges = [
          "192.168.0.0/16"
          "fd00:c0d9:1c00::/48"
        ];
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

      intune.printer.user = "shijiazhang";
    };

    users.codgi.passwordSecret = "codgi-password";
  };

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
        bilibili.gpuAcceleration = "nvidia";
        dev.dotnet.enable = true;
        github-copilot-cli.enable = true;
        git.directoryIdentities = {
          "/code/" = "work";
          "~/GitHub/" = "personal";
        };
        herdr = {
          desktop.enable = true;
          ovis = {
            enable = true;
          };
        };

        plasma = {
          scale = 1.5;
          krdp.enable = true;
        };

        easyeffects.enable = true;
      };

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

  boot.loader.systemd-boot.consoleMode = "max";

  # Global packages
  environment.systemPackages = with pkgs; [
    google-chrome
  ];

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

  system.stateVersion = "26.05";
}
