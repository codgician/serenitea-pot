{ pkgs, ... }:
{
  # My settings
  codgician = {
    system = {
      brew = {
        enable = true;
        taps = [ "playcover/playcover" ];
        casks = (import ./brew.nix).casks;
        masApps = (import ./brew.nix).masApps;
      };
      common.enable = true;
      nix.useCnMirror = true;
    };

    users.codgi.enable = true;
  };

  system.primaryUser = "codgi";

  # Home manager
  home-manager.users.codgi =
    { pkgs, ... }:
    {
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
        stateVersion = "24.11";
        packages =
          with pkgs;
          [
            jq
            dnsutils
            httplz
            iperf3
            htop
            aria2
            android-tools
            scrcpy
            pandoc
            acpica-tools
            terraform
            smartmontools
            ffmpeg-full
            tcping-go
            github-copilot-cli
            binwalk
            imhex
            ghidra
            prismlauncher-unwrapped
          ]
          ++ (with pkgs.nur.repos.codgician; [
            mtk_uartboot
          ]);

        # symlinks to binaries
        file = {
          ".local/bin/jdk8".source = pkgs.zulu8;
        };
      };
    };

  # System packages
  environment.systemPackages = with pkgs; [
    fastfetch
    zulu
    openssl
  ];

  # System settings
  system.defaults = {
    dock = {
      largesize = 128;
      tilesize = 64;
      magnification = true;
      persistent-apps = [
        "/System/Applications/Launchpad.app"
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/System/Applications/Maps.app"
        "/System/Applications/Photos.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Contacts.app"
        "/System/Applications/Reminders.app"
        "/System/Applications/Notes.app"
        "/System/Applications/Freeform.app"
        "/System/Applications/TV.app"
        "/System/Applications/Music.app"
        "/System/Applications/News.app"
        "/System/Applications/App Store.app"
        "/System/Applications/System Settings.app"
        "/System/Applications/iPhone Mirroring.app"
      ];
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
