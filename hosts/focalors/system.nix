{ config, lib, pkgs, ... }:
let
  wallpaper = (pkgs.fetchurl {
    url = "https://cdn.dynamicwallpaper.club/wallpapers/zt6aeujg1pn/Furina.heic";
    sha256 = "1n8ckyhkbsadilwx171kyw44ivp0z7dhz837p1f5jy3zh811bab6";
  }).outPath;
in
{
  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;
      plasma = {
        enable = true;
        autoLoginUser = "codgi";
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    codgician.codgi = {
      dev = {
        haskell.enable = true;
        rust.enable = true;
      };
      
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      vscode.enable = true;
      zsh.enable = true;
    };

    programs.plasma = {
      workspace = { inherit wallpaper; };
      configFile = {
        plasmarc.Wallpapers.usersWallpapers = wallpaper;
        kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General" = {
          Image = wallpaper;
          PreviewImage = wallpaper;
        };
        kwinrc = {
          Xwayland.Scale = 2;
          Wayland."InputMethod[$e]" = "${pkgs.fcitx5}/share/applications/fcitx5-wayland-launcher.desktop";
        };
      };
    };

    home.stateVersion = "24.05";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  # Hyprland
  services.hypridle.enable = true;
  programs.hyprlock.enable = true;
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "breeze";
  };

  fileSystems."/nix/persist".neededForBoot = true;

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
    inputMethod = {
      enabled = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [
          fcitx5-rime
          rime-data
          fcitx5-chinese-addons
        ];
        waylandFrontend = true;
        plasma6Support = true;
      };
    };
  };

  # Configure fonts
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      cascadia-code
    ];
  };

  # Enable pipewire.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.kdeconnect.enable = true;

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  nix.settings.trusted-users = [ "root" "@wheel" ];

  # Global packages
  environment.systemPackages = with pkgs; [
    firefox
    virt-manager
    kitty
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
  system.stateVersion = "24.05"; # Did you read the comment?
}
