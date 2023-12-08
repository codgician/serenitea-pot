{ config, pkgs, ... }:
let
  pubKeys = import ../../pubkeys.nix;
  secretsDir = builtins.toString ../../secrets;
  ageSecrets = builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj));
in
{
  imports = [
    ./hardware.nix

    # User
    ../../users/bmc/default.nix
    ../../users/codgi/default.nix

    # Service modules
    ../../services/acme.nix
    ../../services/conduit.nix
    ../../services/fastapi-dls.nix
    ../../services/gitlab.nix
    ../../services/home-assistant.nix
    ../../services/mesh-commander.nix
    ../../services/nginx.nix
    ../../services/samba.nix
    ../../services/upgrade-pg-cluster.nix
    ../../services/vscode-server.nix
  ];

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    imports = [
      ../../users/codgi/git.nix
      ../../users/codgi/zsh.nix
    ];

    home.stateVersion = "23.11";
    home.packages = with pkgs; [ httplz rnix-lsp iperf3 screen ];
  };

  # Use systemd-networkd
  networking.useNetworkd = true;

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

  # Security
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [ "root" "@wheel" ];

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    neofetch
    wget
    xterm
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
  system.stateVersion = "23.11"; # Did you read the comment?
}
