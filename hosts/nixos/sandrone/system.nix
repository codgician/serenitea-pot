{ lib, pkgs, ... }:
{
  codgician = {
    services = {
      fcitx5.enable = true;
      nixos-vscode-server.enable = true;
      plasma.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      common = {
        audio.enable = true;
        inChina = true;
      };
      impermanence.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
    };
  };

  home-manager.users.codgi = {
    codgician.codgi = {
      claude-code.enable = true;
      dev = {
        haskell.enable = true;
        nix.enable = true;
        rust.enable = true;
      };
      git.enable = true;
      herdr.enable = true;
      mcp.enable = true;
      oh-my-pi.enable = true;
      plasma.scale = 1;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      vscode.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";
    home.packages = with pkgs; [
      binwalk
    ];
  };

  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "breeze";
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
    kitty
  ];

  zramSwap.enable = true;

  networking.firewall.enable = false;

  system.stateVersion = "26.05";
}
