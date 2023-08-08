let
  pubKeys = import ../../pubkeys.nix;
in
{ config, pkgs, ... }: {

  imports = [ ./hardware.nix ];

  networking.networkmanager.enable = true;

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

  # Nix
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
    };
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" "codgi" ];
    };
    extraOptions = "experimental-features = nix-command flakes";
  };

  nixpkgs.config.allowUnfree = true;

  # Zsh
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    ohMyZsh = {
      enable = true;
      theme = "half-life";
    };
  };

  # Define user accounts
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.codgi = {
    name = "codgi";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    home = "/home/codgi";
    shell = pkgs.zsh;
    passwordFile = config.age.secrets.codgiPassword.path;
    openssh.authorizedKeys.keys = pubKeys.users.codgi;
  };

  # Security
  security.sudo.wheelNeedsPassword = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    neofetch
    wget
    xterm
    git
    direnv
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Getty
  services.getty.autologinUser = "codgi";

  # Visual Studio Code Server
  services.vscode-server = {
    enable = true;
    extraRuntimeDependencies = with pkgs; [
      direnv
      rnix-lsp
    ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  # Home manager
  home-manager.users.codgi = { config, pkgs, ... }: {
    home.stateVersion = "23.05";

    # git
    programs.git = {
      enable = true;
      lfs.enable = true;
      package = pkgs.gitFull;

      userName = "codgician";
      userEmail = "15964984+codgician@users.noreply.github.com";
      extraConfig.credential.helper = "osxkeychain";
    };
  };
}
