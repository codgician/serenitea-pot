{ pkgs, ... }:
{
  # My settings
  codgician = {
    services = {
      litellm.enable = false; # disable before pyarrow build is fixed
    };
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
        stateVersion = "25.05";
        packages =
          with pkgs;
          [
            jq
            dnsutils
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
            binwalk
            imhex
            ghidra
            prismlauncher-unwrapped
            macmon
            ollama
            nexttrace
            codex
            claude-code
          ]
          ++ (with pkgs.nur.repos.codgician; [
            mtk_uartboot
            nanokvm-usb
          ]);

        # symlinks to binaries
        file = {
          ".local/bin/jdk8".source = pkgs.zulu8;
        };
      };
    };

  environment = {
    # System packages
    systemPackages = with pkgs; [
      fastfetch
      zulu
      openssl
    ];

    # SMB client settings
    etc."nsmb.conf".text = ''
      [default]
      mc_on=no
      mc_prefer_wired=yes
    '';
  };

  # System settings
  system.defaults = {
    dock = {
      largesize = 128;
      tilesize = 64;
      magnification = true;
      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/Messages.app"
        "/System/Applications/Mail.app"
        "/System/Applications/Maps.app"
        "/System/Applications/Photos.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Phone.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Contacts.app"
        "/System/Applications/Reminders.app"
        "/System/Applications/Notes.app"
        "/System/Applications/TV.app"
        "/System/Applications/Music.app"
        "/System/Applications/Games.app"
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

  system.stateVersion = 6;
}
