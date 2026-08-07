{ lib, pkgs, ... }:
let
  wallpaper =
    (pkgs.fetchurl {
      url = "https://media.githubusercontent.com/media/codgician/assets/refs/heads/main/images/wallpapers/genshin-luna-viii.jpg";
      sha256 = "sha256-VjoCRP8AENaUlItKCn2751GY+WtF0ncwcBWYuJHmCWE=";
    }).outPath;
in
{

  # My settings
  codgician = {
    services = {
      fcitx5.enable = true;
      nixos-vscode-server.enable = true;
      plasma.enable = true;
      hyprland = {
        enable = false;
        monitors = [
          {
            output = "DP-3";
            mode = "3840x2160@60";
            position = "0x0";
            scale = 1.5;
          }
          {
            output = "HDMI-A-1";
            mode = "3840x2160@60";
            position = "2560x0";
            scale = 1.5;
          }
        ];
      };

      sing-box = {
        enable = true;
        clients.ss-lumidouce = {
          enable = true;
          bindInterface = "eno1-guest";
        };
        tun = {
          enable = true;
          outbound = "outbound-ss-lumidouce";
          stack = "mixed";
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
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      passwordAgeFile = getAgeSecretPathFromName "codgi-password";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
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
        codex = {
          enable = true;
          package = pkgs.codex-wrapped;
        };
        claude-code.enable = true;
        dev = {
          dotnet.enable = true;
          nix.enable = true;
        };
        opencode.enable = true;
        mcp.enable = true;
        oh-my-pi = {
          enable = true;
          defaultProfile = "github-copilot";
        };
        github-copilot-cli.enable = true;
        git = {
          enable = true;
          directoryIdentities = {
            "/code/" = "work";
            "~/GitHub/" = "personal";
          };
        };

        plasma = {
          inherit wallpaper;
          scale = 1.5;
          krdp = {
            enable = true;
            port = 3389;
            quality = 75;
          };
          launchers = [
            "applications:org.kde.dolphin.desktop"
            "applications:microsoft-edge.desktop"
            "applications:org.kde.konsole.desktop"
            "applications:code.desktop"
            "applications:teams-for-linux.desktop"
          ];
        };

        pwsh.enable = true;
        ssh.enable = true;
        tmux.enable = true;
        vscode.enable = true;
        zsh.enable = true;
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
          cider-2
          splayer
          easyeffects
          virt-manager
          looking-glass-client-nvhack
          telegram-desktop
          nextcloud-talk-desktop
          element-desktop
          discord
          voxtype-onnx
          moonlight-qt
        ]
        ++ (with pkgs.nur.repos.codgician; [
          nanokvm-usb
        ]);
    };

  # Enable Network Manager (leave thunderbolt0 to systemd-networkd)
  networking.networkmanager = {
    enable = true;
    unmanaged = [ "thunderbolt0" ];

    ensureProfiles.profiles."eno1-guest" = {
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
  networking.hostId = "357a80da";

  # Plasma Login Manager currently reads wallpaper configuration from the main file.
  environment.etc."plasmalogin.conf".text = ''
    [Greeter][Wallpaper][org.kde.image][General]
    Image=file://${wallpaper}
  '';

  # DNS for sing-box TUN (matchConfig supplied by the sing-box module)
  systemd.network = {
    wait-online.enable = false;
    networks."50-sing-box-tun" = {
      dns = [ "192.168.0.1" ];
      domains = [
        "~cdu"
        "~lan"
        "~codgician.me"
      ];
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "nixos-bgrt";
    themePackages = [ pkgs.nixos-bgrt-plymouth ];
  };

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  codgician.system.common.audio.enable = true;

  services.fwupd.enable = true;

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Global packages
  environment.systemPackages = with pkgs; [
    google-chrome
    firefox-bin
  ];

  # Enable zram swap
  zramSwap.enable = true;

  # Disable auto-suspend: NVIDIA s2idle resume deadlocks the host.
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
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

  # Firewall
  networking.firewall = {
    enable = false;
    allowedTCPPorts = [ 3389 ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
