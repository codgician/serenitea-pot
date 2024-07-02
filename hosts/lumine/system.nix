{ config, lib, pkgs, agenix, ... }: {

  # My settings
  codgician = {
    services = {
      nixos-vscode-server.enable = true;

      nginx = {
        enable = true;
        reverseProxies = {
          "amt.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "amt.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "books.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "books.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "bubbles.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "bubbles.codgician.me" ];
            locations."/".proxyPass = "http://192.168.0.9:1234";
          };

          "fin.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "fin.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.8";
          };

          "git.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "git.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "hass.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "hass.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.6";
          };

          "pve.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "pve.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.21:8006";
          };

          "matrix.codgician.me" = {
            enable = true;
            https = true;
            domains = [ "matrix.codgician.me" ];
            locations."/".proxyPass = "https://192.168.0.7";
          };

          "codgician.me" = {
            enable = true;
            https = true;
            default = true;
            domains = [ "codgician.me" "*.codgician.me" ];
            locations."/".root = import ./lumine-web.nix { inherit pkgs; };
          };
        };
      };

      wireguard = {
        enable = true;
        interfaces.wg0 = {
          host = "lumine";
          peers = [ "suzhou" ];
          allowedIPsAsRoutes = true;
        };
      };
    };

    system.agenix.enable = true;

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

  networking.useNetworkd = true;
  services.resolved.enable = true;

  # Use the systemd-boot EFI boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    fastfetch
    wget
    xterm
    htop
    wireguard-tools
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
