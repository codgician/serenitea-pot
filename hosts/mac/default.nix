{ config, pkgs, lib, ... }: {

  imports = [
    # Users
    ../../users/codgi/default.nix
  ];

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    imports = [
      ../../users/codgi/pwsh.nix
      ../../users/codgi/git.nix
      ../../users/codgi/ssh.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.11";
    home.packages = with pkgs; [
      httplz
      rnix-lsp
      iperf3
      android-tools
      aria2
      ghc
      pandoc
      acpica-tools
      terraform
      crate2nix
      go
      gopls
      go-outline
      smartmontools
      pciutils
      ffmpeg-full
    ];

    # symlinks to binaries
    home.file = {
      ".local/bin/jdk8".source = pkgs.zulu8;
    };
  };

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    interval = {
      Hour = 24 * 7;
      Minute = 0;
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    neofetch
    zulu
    openssl
  ];

  # Fonts
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [ cascadia-code ];
  };

  # zsh
  programs.zsh = {
    enable = true;
    promptInit = "";
  };

  # Enable Touch ID for sudo
  security.pam.enableSudoTouchIdAuth = true;

  # Disable ssh password authentication
  environment.etc."ssh/sshd_config.d/110-no-password-authentication.conf" = {
    text = "PasswordAuthentication no";
  };

  # Homebrew
  homebrew =
    let
      brew = import ./brew.nix;
      masApps = brew.masApps;
      casks = brew.casks;
    in
    {
      enable = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };

      inherit masApps;
      inherit casks;
    };
}
