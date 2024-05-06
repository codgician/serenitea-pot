{ config, lib, pkgs, agenix, ... }:
{
  imports = [ ./hardware.nix ];

  # My settings
  codgician = {
    services = {
      comfyui = {
        enable = true;
        dataDir = "/nix/persist/comfyui";
        reverseProxy = {
          enable = true;
          domains = [ "comfy.codgician.me" ];
        };
      };

      jellyfin = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "fin.codgician.me" ];
        };
      };
      nixos-vscode-server.enable = true;
    };

    system = {
      agenix.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
      extraGroups = [ "wheel" "podman" ];
    };

    virtualization.podman.enable = true;
  };

  # Home manager
  home-manager.users.codgi = { config, ... }: rec {
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "23.11";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useNetworkd = true;
  services.resolved = {
    enable = true;
    extraConfig = ''
      Cache=no-negative
    '';
  };

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  # Configure keymap in X11
  services.xserver = {
    enable = false;
    xkb.layout = "us";
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

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
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

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  # Hack
  systemd.services.nix-daemon.environment.TMPDIR = "/nix/tmp/nix-daemon";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
