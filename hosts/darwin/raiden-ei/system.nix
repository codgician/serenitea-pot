{ pkgs, ... }:
{
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
        dev.nix.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.05";
      home.packages = with pkgs; [
        httplz
        iperf3
        htop
        aria2
      ];
    };

  environment.systemPackages = with pkgs; [
    fastfetch
    openssl
  ];

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
      persistent-apps = [
        "/System/Applications/Apps.app"
        "/System/Cryptexes/App/System/Applications/Safari.app"
        "/System/Applications/Messages.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Home.app"
        "/System/Applications/FindMy.app"
        "/System/Applications/Utilities/Terminal.app"
        "/System/Applications/App Store.app"
        "/System/Applications/System Settings.app"
        "/Applications/BlueBubbles.app"
      ];
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
      AppleMetricUnits = 1;
      NSAutomaticWindowAnimationsEnabled = false;
      NSScrollAnimationEnabled = false;
    };

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    universalaccess = {
      reduceMotion = true;
      reduceTransparency = true;
    };
  };

  system.stateVersion = 6;
}
