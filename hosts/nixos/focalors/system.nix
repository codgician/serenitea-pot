{ pkgs, ... }:
{
  codgician = {
    services = {
      fcitx5.enable = true;
      nixos-vscode-server.enable = true;
      plasma = {
        enable = true;
        wallpaper =
          (pkgs.fetchurl {
            url = "https://web.archive.org/web/20240727142306if_/https://cdn.dynamicwallpaper.club/wallpapers/zt6aeujg1pn/Furina.heic";
            sha256 = "1n8ckyhkbsadilwx171kyw44ivp0z7dhz837p1f5jy3zh811bab6";
          }).outPath;
      };
    };

    system = {
      auto-upgrade.enable = true;
      common = {
        audio.enable = true;
        inChina = true;
      };
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi.enable = true;
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      dev = {
        haskell.enable = true;
        nix.enable = true;
        rust.enable = true;
      };
      git.enable = true;
      mcp.enable = true;
      oh-my-pi.enable = true;
      plasma.scale = 2;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      vscode.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";
    home.packages = with pkgs; [
      screen
      binwalk
    ];
  };

  networking.networkmanager.enable = true;
  networking.hostId = "41182c40";

  boot.loader.systemd-boot.enable = true;
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

  environment.systemPackages = with pkgs; [
    firefox-bin
    google-chrome
    virt-manager
    kitty
  ];

  zramSwap.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
