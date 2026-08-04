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
      common.inChina = true;
    };

    users.codgi.enable = true;
  };

  # Avoid uncached Haskell closures on legacy x86_64-darwin. nix-darwin only
  # needs the ShellCheck executable, and nix-fast-build can run without its
  # optional nix-output-monitor integration.
  nixpkgs.overlays = [
    (_final: prev: {
      shellcheck = prev.stdenvNoCC.mkDerivation {
        pname = "shellcheck-bin";
        version = "0.11.0";
        src = prev.fetchurl {
          url = "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.x86_64.tar.xz";
          hash = "sha256-PInbTtyrfPHCe/8XiILg9vJ/ev31ToWfoEH8oQ/r5MY=";
        };
        installPhase = ''
          runHook preInstall
          install -Dm755 shellcheck "$out/bin/shellcheck"
          runHook postInstall
        '';
      };
      nix-fast-build = prev.nix-fast-build.override {
        nix-output-monitor = {
          compiler.meta.platforms = [ ];
        };
      };
    })
  ];

  # The bundled uninstaller evaluates a separate system that cannot inherit
  # the ShellCheck override above, so do not include it on this host.
  system.tools.darwin-uninstaller.enable = false;

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
        tmux.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "26.05";
      home.packages = with pkgs; [
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

  system.stateVersion = 7;
}
