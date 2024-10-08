{ pkgs, ... }: {

  # My settings
  codgician = {
    system = {
      brew = {
        enable = true;
        casks = [
          "bluebubbles"
          "opencore-configurator"
        ];
        masApps = { };
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
      aria2
      httping
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [ fastfetch openssl ];

  # zsh
  programs.zsh = {
    enable = true;
    promptInit = "";
  };

  system.defaults = {
    dock = {
      launchanim = false;
      magnification = false;
      mineffect = "scale";
    };

    loginwindow = {
      autoLoginUser = "codgi";
      SleepDisabled = true;
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleTemperatureUnit = "Celsius";
      AppleMeasurementUnits = "Centimeters";
      NSAutomaticWindowAnimationsEnabled = false;
      NSScrollAnimationEnabled = false;
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    universalaccess = {
      reduceMotion = true;
      reduceTransparency = true;
    };
  };

  system.stateVersion = 5;
}
