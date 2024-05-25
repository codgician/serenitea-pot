{ config, pkgs, lib, ... }: {

  # My settings
  codgician = {
    system = {
      agenix.enable = true;
      brew = {
        enable = true;
        taps = [ "playcover/playcover" ];
        casks = (import ./brew.nix).casks;
        masApps = (import ./brew.nix).masApps;
      };
    };

    users.codgi.enable = true;
  };

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "24.05";
    home.packages = with pkgs; [
      httplz
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
      httping
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

  nixpkgs.config.allowUnfree = true;

  # Disable ssh password authentication
  environment.etc."ssh/sshd_config.d/110-no-password-authentication.conf" = {
    text = "PasswordAuthentication no";
  };

  # System settings
  system.defaults = {
    dock = {
      largesize = 128;
      magnification = true;
    };

    NSGlobalDomain.AppleTemperatureUnit = "Celsius";
    
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
  };
}
