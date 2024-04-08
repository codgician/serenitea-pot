{ config, pkgs, ... }:
{
  imports = [
    ./hardware.nix

    # Service modules
    ../../profiles/nixos/acme.nix
    ../../profiles/nixos/dendrite.nix
    ../../profiles/nixos/gitlab.nix
    ../../profiles/nixos/upgrade-pg-cluster.nix
  ];

  # My settings
  codgician = {
    services = rec {
      calibre-web = {
        enable = true;
        port = 3002;
        calibreLibrary = "/mnt/nas/media/books";
      };

      fastapi-dls = rec {
        enable = true;
        host = "nvdls.codgician.me";
        port = 4443;
        announcePort = 443;
        appDir = "/var/lib/fastapi-dls-app";
        dataDir = "/mnt/data/fastapi-dls";
      };

      meshcommander = {
        enable = true;
        port = 3001;
      };

      nixos-vscode-server.enable = true;

      nginx = {
        enable = true;
        reverseProxies = {
          "amt.codgician.me" = {
            enable = true;
            proxyPass = "http://127.0.0.1:${builtins.toString meshcommander.port}";
            https = true;
            domains = [ "amt.codgician.me" ];
            extraConfig = ''
              proxy_buffering off;
            '';
          };

          "books.codgician.me" = {
            enable = true;
            proxyPass = "http://127.0.0.1:${builtins.toString calibre-web.port}";
            https = true;
            domains = [ "books.codgician.me" ];
          };

          "nvdls.codgician.me" = {
            enable = true;
            proxyPass = "https://127.0.0.1:${builtins.toString fastapi-dls.port}";
            https = true;
            domains = [ "nvdls.codgician.me" ];
            lanOnly = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      };

      samba = {
        enable = true;
        users = [ "codgi" "bmc" ];
        shares = {
          "media" = {
            path = "/mnt/nas/media";
            browsable = "yes";
            writeable = "yes";
            "read only" = "no";
            "guest ok" = "yes";
            "create mask" = "0644";
            "directory mask" = "0755";
            "force user" = "codgi";
          };

          "iso" = {
            path = "/mnt/nas/iso";
            public = "yes";
            browsable = "yes";
            writeable = "yes";
            "guest ok" = "yes";
            "create mask" = "0644";
            "directory mask" = "0755";
            "force user" = "codgi";
          };

          "timac" = {
            path = "/mnt/timac/";
            "valid users" = "codgi";
            public = "no";
            writeable = "yes";
            "force user" = "codgi";
            "fruit:aapl" = "yes";
            "fruit:time machine" = "yes";
            "vfs objects" = "catia fruit streams_xattr";
          };
        };
      };
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
          passwordAgeFile = secretsDir + "/codgiPassword.age";
          extraGroups = [ "wheel" ];
        };
        bmc = {
          enable = true;
          createHome = false;
          hashedPasswordAgeFile = secretsDir + "/bmcHashedPassword.age";
          passwordAgeFile = secretsDir + "/bmcPassword.age";
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

  networking.useNetworkd = true;
  services.resolved.enable = true;

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
