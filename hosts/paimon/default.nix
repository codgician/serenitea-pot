{ config, pkgs, ... }:
{
  imports = [
    ./hardware.nix

    # Service modules
    ../../profiles/nixos/acme.nix
    ../../profiles/nixos/calibre-web.nix
    ../../profiles/nixos/dendrite.nix
    ../../profiles/nixos/gitlab.nix
    ../../profiles/nixos/mesh-commander.nix
    ../../profiles/nixos/samba.nix
    ../../profiles/nixos/upgrade-pg-cluster.nix
  ];

  # My settings
  codgician = {
    services = {
      fastapi-dls = rec {
        enable = true;
        host = "nvdls.codgician.me";
        announcePort = 443;
        appDir = "/var/lib/fastapi-dls-app";
        dataDir = "/mnt/data/fastapi-dls";
        reverseProxy = {
          enable = true;
          https = true;
          lanOnly = true;
          domains = [
            host
            "sz.codgician.me"
            "sz4.codgician.me"
            "sz6.codgician.me"
          ];
        };
      };
      nixos-vscode-server.enable = true;
    };

    system.agenix.enable = true;

    users =
      let
        secretsDir = ../../secrets;
      in
      {
        codgi = {
          enable = true;
          hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
          extraAgeFiles = [ (secretsDir + "/codgiPassword.age") ];
          extraGroups = [ "wheel" ];
        };
        bmc = {
          enable = true;
          createHome = false;
          hashedPasswordAgeFile = secretsDir + "/bmcHashedPassword.age";
          extraAgeFiles = [ (secretsDir + "/bmcPassword.age") ];
        };
      };
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    imports = [
      ../../profiles/hm/git.nix
      ../../profiles/hm/zsh.nix
    ];

    home.stateVersion = "23.11";
    home.packages = with pkgs; [ httplz iperf3 screen ];
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
