{ lib, pkgs, ... }:
{
  # My settings
  codgician = {
    services = {
      fcitx5.enable = true;
      nixos-vscode-server.enable = true;
      plasma.enable = true;
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence.enable = true;
      secure-boot.enable = false;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      extraGroups = [
        "wheel"
        "video"
        "render"
      ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev = {
          haskell.enable = true;
          nix.enable = true;
          rust.enable = true;
        };

        claude-code.enable = true;
        git.enable = true;
        mcp.enable = true;
        oh-my-pi.enable = true;
        opencode.enable = true;
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

  # Enable Network Manager
  networking.networkmanager.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "breeze";
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

  # Global packages
  environment.systemPackages = with pkgs; [
    firefox
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
  system.stateVersion = "26.05"; # Did you read the comment?
}
