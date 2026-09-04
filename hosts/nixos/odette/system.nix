{ lib, pkgs, ... }:
let
  wallpaper =
    (pkgs.fetchurl {
      url = "https://media.githubusercontent.com/media/codgician/assets/refs/heads/main/images/wallpapers/genshin-luna-viii.jpg";
      sha256 = "sha256-VjoCRP8AENaUlItKCn2751GY+WtF0ncwcBWYuJHmCWE=";
    }).outPath;
in
{
  codgician = {
    services = {
      fcitx5.enable = true;
      nixos-vscode-server.enable = true;
      plasma.enable = true;
      rasdaemon.enable = true;
      intune = {
        enable = true;
        vpn.enable = true;
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    virtualization.podman.enable = true;

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      extraGroups = [
        "wheel"
        "video"
        "render"
        "podman"
      ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        bilibili = {
          enable = true;
          gpuAcceleration = "intel";
        };
        dev = {
          haskell.enable = true;
          nix.enable = true;
          rust.enable = true;
        };

        claude-code.enable = true;
        git = {
          enable = true;
          directoryIdentities = {
            "~/Work/" = "work";
            "~/GitHub/" = "personal";
          };
          send-email.enable = true;
        };
        herdr.enable = true;
        mcp.enable = true;
        oh-my-pi.enable = true;
        opencode.enable = true;
        plasma = {
          inherit wallpaper;
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
        tmux.enable = true;
        vscode.enable = true;
        zsh.enable = true;

        easyeffects = {
          enable = true;
          presets = {
            "ChromeOS Redrix".content = ./easyeffects/chromeos-redrix.json;
            Nothing.content = {
              blocklist = [ ];
              plugins_order = [ ];
            };
          };
          autoload = [
            {
              device = "alsa_output.pci-0000_00_1f.3-platform-adl_rt5682_def.HiFi__Speaker__sink";
              deviceDescription = "Alder Lake PCH-P High Definition Audio Controller Speaker";
              deviceProfile = "HiFi: Speaker: sink";
              preset = "ChromeOS Redrix";
            }
          ];
          fallback.output = "Nothing";
        };
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
        }
      ];

      home.stateVersion = "26.05";
      home.packages = with pkgs; [
        yubikey-manager
        yubico-piv-tool
        unstable.cider-2
        splayer
        telegram-desktop
        nextcloud-talk-desktop
        element-desktop
        discord
        voxtype-onnx
        moonlight-qt
        gimp
      ];
    };

  # Enable Network Manager
  networking.networkmanager.enable = true;

  # Use the systemd-boot EFI boot loader.
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

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  codgician.system.common.audio.enable = true;

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
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

  # Enable zram swap
  zramSwap.enable = true;

  # Firewall
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
