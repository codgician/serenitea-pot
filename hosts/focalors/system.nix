{ config, lib, pkgs, ... }: {

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;
      plasma = {
        enable = true;
        autoLoginUser = "codgi";
      };
    };

    system = {
      agenix.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "24.05";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.plymouth.enable = true;

  networking.useNetworkd = true;
  services.resolved = {
    enable = true;
    extraConfig = ''
      MulticastDNS=yes
      Cache=no-negative
    '';
  };

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
    inputMethod = {
      enabled = "fcitx5";
      fcitx5 = {
        addons = with pkgs; [ fcitx5-rime fcitx5-chinese-addons ];
        waylandFrontend = true;
      };
    };
  };

  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

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

  # Zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  # Configure fonts
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      cascadia-code
    ];
  };

  # Enable sound with pipewire.
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  programs.kdeconnect.enable = true;

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  nix.settings.trusted-users = [ "root" "@wheel" ];

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    fastfetch
    wget
    xterm
    htop
    firefox
    vscode
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Hack
  systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp/nix-daemon";

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
