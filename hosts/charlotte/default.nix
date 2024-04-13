{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./hardware.nix
    ./tpm.nix
  ];

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

    system.agenix.enable = true;

    users = with lib.codgician; {
      codgi = {
        enable = true;
        hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
        extraGroups = [
          "dialout"
          "feedbackd"
          "networkmanager"
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
  home-manager.users.codgi = { config, pkgs, ... }: {
    imports = [
      ../../profiles/hm/pwsh.nix
      ../../profiles/hm/git.nix
      ../../profiles/hm/ssh.nix
      ../../profiles/hm/zsh.nix
    ];

    home.stateVersion = "23.11";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Auto upgrade
  system.autoUpgrade = {
    enable = true;
    dates = "daily";
    operation = "switch";
    allowReboot = true;
    rebootWindow = {
      lower = "03:00";
      upper = "05:00";
    };
  };

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    neofetch
    wget
    xterm
    htop
    firefox
    maliit-framework
    maliit-keyboard
  ];

  # Zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  # Enable the OpenSSH daemon
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  nixpkgs.config.allowUnfree = true;

  # Use Network Manager
  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

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

  # It's recommended to keep enabled on these constrained devices
  zramSwap.enable = true;

  #
  # User configuration
  #
  users.mutableUsers = false;

  security.sudo.wheelNeedsPassword = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
