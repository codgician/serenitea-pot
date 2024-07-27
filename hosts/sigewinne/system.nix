{ config, lib, pkgs, inputs, ... }: {

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;
      plasma = {
        enable = true;
        autoLoginUser = "kiosk";
        displayManager = "lightdm";
      };
    };

    system = {
      agenix.enable = true;
      auto-upgrade.enable = true;
      common.enable = true;
    };

    users = with lib.codgician; {
      codgi = {
        enable = true;
        hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
        extraGroups = [
          "dialout"
          "feedbackd"
          "video"
          "wheel"
          "tss"
        ];
      };

      kiosk = {
        enable = true;
        hashedPasswordAgeFile = secretsDir + "/kioskHashedPassword.age";
      };
    };
  };

  # Enable dconf
  programs.dconf.enable = true;

  # Auto unlock Kwallet
  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

  # Home manager
  home-manager.users = {
    codgi = { config, pkgs, ... }: {
      codgician.codgi = {
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "24.05";
      home.packages = with pkgs; [ httplz iperf3 screen ];
    };

    kiosk = { config, osConfig, pkgs, ... }: {
      home.stateVersion = "24.05";

      # Plasma settings
      programs.plasma = {
        enable = osConfig.codgician.services.plasma.enable;

        powerdevil = {
          powerButtonAction = "showLogoutScreen";
          autoSuspend.action = "nothing";
          turnOffDisplay.idleTimeout = "never";
        };

        configFile = {
          kscreenlockerrc.Daemon = {
            Autolock = false;
            LockGrace = 0;
            LockOnResume = false;
          };

          kwinrc = {
            Wayland = {
              "InputMethod[$e]" = "${pkgs.maliit-keyboard}/share/applications/com.github.maliit.keyboard.desktop";
              VirtualKeyboardEnabled = true;
            };
            XWayland.Scale = 1.75;
          };
        };
      };

      # Autostart
      home.file.".config/autostart/kiosk.desktop".text =
        lib.mkIf osConfig.codgician.services.plasma.enable ''
          [Desktop Entry]
          Exec=firefox --kiosk https://hass.codgician.me
          Icon=firefox
          Name=Kiosk
          StartupNotify=true
          StartupWMClass=firefox
          Terminal=false
          Type=Application
        '';
    };
  };

  # Global packages
  environment.systemPackages = with pkgs; [
    firefox
    maliit-framework
    maliit-keyboard
  ];

  # Firmware
  hardware.firmware = [ config.mobile.device.firmware ];
  hardware.enableRedistributableFirmware = true;

  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    extraPackages = [
      pkgs.vaapiVdpau
      pkgs.libvdpau-va-gl
    ];
  };

  # Use PulseAudio
  hardware.pulseaudio.enable = true;

  # Enable Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Bluetooth audio
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  # Enable power management options
  powerManagement.enable = true;

  # Enable zram swap
  zramSwap.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
