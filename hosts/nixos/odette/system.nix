{ pkgs, ... }:
{
  codgician = {
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
      rasdaemon.enable = true;
      intune = {
        enable = true;
        printer = {
          enable = true;
          user = "shijiazhang";
        };
      };
      sing-box = {
        enable = true;
        autoStart = false;
        clients.ss-lumidouce.enable = true;
        tun = {
          enable = true;
          routedRanges = [
            "0.0.0.0/0"
            "::/0"
          ];
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      common.audio.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    virtualization.podman.enable = true;

    users.codgi.enable = true;
  };

  services.vscode-server.enable = true;

  home-manager.users.codgi = {
    codgician.codgi = {
      bilibili = {
        enable = true;
        gpuAcceleration = "intel";
      };
      claude-code.enable = true;
      codex.enable = true;
      dev = {
        haskell.enable = true;
        nix.enable = true;
        rust.enable = true;
      };

      pi-coding-agent.enable = true;
      git = {
        directoryIdentities = {
          "~/Work/" = "work";
          "~/GitHub/" = "personal";
        };
        send-email.enable = true;
      };
      herdr.enable = true;
      mcp.enable = true;
      oh-my-pi = {
        enable = true;
        defaultProfile = "github-copilot";
      };
      plasma = {
        scale = 1.5;
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
      teams-for-linux.enable = true;
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

    # HP Elite Dragonfly Chromebook's ELAN touchpad. Plasma on Wayland
    # reads input settings from kcminputrc (via KWin/libinput), not from
    # `services.libinput.*`, which only applies under Xorg.
    programs.plasma.input.touchpads = [
      {
        name = "ELAN2703:00 04F3:323B Touchpad";
        vendorId = "04F3";
        productId = "323B";
        naturalScroll = true;
        tapToClick = false;
      }
    ];

    # Keep existing lid/idle policies, but use battery-aware sleep in every profile.
    programs.plasma.powerdevil = {
      AC.whenSleepingEnter = "standbyThenHibernate";
      battery.whenSleepingEnter = "standbyThenHibernate";
      lowBattery.whenSleepingEnter = "standbyThenHibernate";
    };

    home.stateVersion = "26.05";
    home.packages = with pkgs; [
      yubikey-manager
      yubico-piv-tool
      unstable.cider-2
      unstable.splayer-next
      telegram-desktop
      nextcloud-talk-desktop
      element-desktop
      discord
      voxtype-onnx
      moonlight-qt
      gimp
      kdePackages.cantor
      kdePackages.kalgebra
      drawy
      chatgpt-wrapped
      azure-cli
      # QCAD replaces Qt's plugin paths at startup; expose QtWayland in its own plugin directory.
      (unstable.qcad.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [ unstable.qt5.qtwayland ];
        postInstall = (old.postInstall or "") + ''
          for plugin in wayland-shell-integration wayland-graphics-integration-client wayland-decoration-client; do
            ln -s ${unstable.qt5.qtwayland.bin}/${unstable.qt5.qtbase.qtPluginPrefix}/$plugin $out/lib/plugins/$plugin
          done
        '';
      }))
    ];
  };

  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "nixos-bgrt";
    themePackages = [ pkgs.nixos-bgrt-plymouth ];
    # Auto-detected DeviceScale defaults to 2 on this 201 DPI panel, but
    # Plymouth only supports integer scaling (no 1.5 like the Plasma
    # session), so pin it to 1 to keep boot splash/prompt text a sane size.
    extraConfig = ''
      DeviceScale=1
    '';
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

  networking.hostId = "000de77e";

  # Global packages
  environment.systemPackages = with pkgs; [
    google-chrome
    microsoft-edge
  ];

  zramSwap.enable = true;

  # Outside Plasma, logind handles lid and suspend-key requests directly.
  # Leave HibernateDelaySec unset: systemd hibernates on low battery, not a timer.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
  };

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
