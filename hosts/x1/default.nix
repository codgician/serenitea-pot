let
  pubKeys = import ../../pubkeys.nix;
in
{ config, pkgs, ... }: {
  imports =
    [
      ./hardware.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth.enable = true;

  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  # Enable swap on luks
  boot.initrd.luks.devices."luks-82a3afab-1091-4970-9f97-b24e5bd9744f".device = "/dev/disk/by-uuid/82a3afab-1091-4970-9f97-b24e5bd9744f";
  boot.initrd.luks.devices."luks-82a3afab-1091-4970-9f97-b24e5bd9744f".keyFile = "/crypto_keyfile.bin";

  # Virtualisation
  virtualisation = {
    libvirtd.enable = true;
    lxc.enable = true;
    lxd.enable = true;
    waydroid.enable = true;
  };

  # TPM
  security.tpm2 = {
    enable = true;
    # pkcs11.enable = true;
    tctiEnvironment.enable = true;
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

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
  };

  # Enable networking
  networking.networkmanager.enable = true;

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
      fcitx5.addons = with pkgs; [ fcitx5-rime fcitx5-chinese-addons ];
    };
  };

  # Configure fonts
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
    ];
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "displaylink" "modesetting" ];

  # Enable the KDE Plasma Desktop Environment.
  services.xserver.displayManager = {
    defaultSession = "plasmawayland";
    sddm = {
      enable = true;
      enableHidpi = true;
      theme = "breeze";
    };
  };

  # Auto unlock Kwallet
  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

  services.xserver.desktopManager.plasma5 = {
    enable = true;
    useQtScaling = true;
  };

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
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

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define user accounts
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.codgi = {
    name = "codgi";
    description = "Shijia Zhang";
    home = "/home/codgi";
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.age.secrets.codgiHashedPassword.path;
    openssh.authorizedKeys.keys = pubKeys.users.codgi;
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: {
    imports = [
      ../../users/codgi/git.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.05";
    home.packages = with pkgs; [
      httplz
      rnix-lsp
      iperf3
      firefox
      vscode
      neofetch
      firefox
      kate
      thunderbird
      vscode
      libreoffice-qt
      telegram-desktop
      qq
      remmina
      breeze-gtk
      microsoft-edge
      cider
      prismlauncher
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    clinfo
    glxinfo
    vulkan-tools
    wayland-utils
    pciutils
    virtmanager
    direnv
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
    config.credential.helper = "libsecret";
  };

  programs.kdeconnect.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures = {
      base = true;
      gtk = true;
    };
  };

  # Dconf
  programs.dconf.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable fprintd
  services.fprintd.enable = true;

  # Enable fwupd
  services.fwupd = {
    enable = true;
    enableTestRemote = true;
    extraRemotes = [ ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
