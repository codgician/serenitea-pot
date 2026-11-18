{ pkgs, ... }:
{
  codgician.services = {
    intune.printer = {
      enable = true;
      user = "shijiazhang";
    };
    sing-box = {
      autoStart = false;
      tun.routedRanges = [
        "0.0.0.0/0"
        "::/0"
      ];
    };
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      bilibili.gpuAcceleration = "intel";
      dev = {
        haskell.enable = true;
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
      plasma.scale = 1.5;
    };

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

  # Auto-detected DeviceScale defaults to 2 on this 201 DPI panel, but
  # Plymouth only supports integer scaling (no 1.5 like the Plasma
  # session), so pin it to 1 to keep boot splash/prompt text a sane size.
  boot.plymouth.extraConfig = ''
    DeviceScale=1
  '';

  networking.hostId = "000de77e";

  # Global packages
  environment.systemPackages = with pkgs; [
    google-chrome
    microsoft-edge
  ];

  # Outside Plasma, logind handles lid and suspend-key requests directly.
  # Leave HibernateDelaySec unset: systemd hibernates on low battery, not a timer.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
  };

  system.stateVersion = "26.05";
}
