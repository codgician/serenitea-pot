{ pkgs, ... }: {

  # My settings
  codgician = {
    system = {
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
      dev = {
        haskell.enable = true;
        nix.enable = true;
        rust.enable = true;
      };

      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      vscode.enable = true;
      zsh.enable = true;
    };

    home = {
      stateVersion = "24.05";
      packages = with pkgs; [
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
        virt-manager
        tcping-go
        httping
      ];

      # symlinks to binaries
      file = {
        ".local/bin/jdk8".source = pkgs.zulu8;
      };
    };
  };

  # Fonts
  fonts.packages = with pkgs; [ cascadia-code ];

  # zsh
  programs.zsh = {
    enable = true;
    promptInit = "";
  };

  # Enable Touch ID for sudo
  security.pam.enableSudoTouchIdAuth = true;

  environment = {
    # Disable ssh password authentication
    etc."ssh/sshd_config.d/110-no-password-authentication.conf" = {
      text = "PasswordAuthentication no";
    };

    # Workaround lack of dbus
    variables."GSETTINGS_BACKEND" = "keyfile";

    # System packages
    systemPackages = with pkgs; [
      fastfetch
      zulu
      openssl
    ];
  };

  # System settings
  system.defaults = {
    dock = {
      largesize = 128;
      magnification = true;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleTemperatureUnit = "Celsius";
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    trackpad.Clicking = true;
  };

  system.stateVersion = 5;
}
