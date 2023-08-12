let
  pubKeys = import ../../pubkeys.nix;
in
{ config, pkgs, ... }: {

  imports = [
    ./hardware.nix

    # Service modules
    ../../services/acme.nix
    ../../services/gitlab.nix
    ../../services/jellyfin.nix
    ../../services/nginx.nix
    ../../services/samba.nix
    ../../services/vscode-server.nix
  ];

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
    passwordFile = config.age.secrets.codgiPassword.path;
    openssh.authorizedKeys.keys = pubKeys.users.codgi;
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: {
    imports = [
      ../../users/codgi/git.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.05";
  };

  # Security
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "root" "@wheel" "codgi" ];

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    neofetch
    wget
    xterm
    direnv
    htop
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Getty
  services.getty.autologinUser = "codgi";

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
}
