{ config, lib, pkgs, ... }: {
  imports = [ ./hardware.nix ];

  # My settings
  codgician = {
    services = rec {
      postgresql = {
        dataDir = "/mnt/postgres";
        zfsOptimizations = true;
      };

      calibre-web = {
        enable = true;
        ip = "127.0.0.1";
        port = 3002;
        calibreLibrary = "/mnt/nas/media/books";
        reverseProxy = {
          enable = true;
          domains = [ "books.codgician.me" ];
        };
      };

      dendrite = {
        enable = true;
        dataPath = "/mnt/data/dendrite";
        domain = "matrix.codgician.me";
        reverseProxy = {
          enable = true;
          elementWeb = true;
        };
      };

      fastapi-dls = {
        enable = true;
        acmeDomain = "nvdls.codgician.me";
        host = "127.0.0.1";
        port = 12443;
        announcePort = 443;
        appDir = "/var/lib/fastapi-dls-app";
        dataDir = "/mnt/data/fastapi-dls";
        reverseProxy.enable = true;
      };

      gitlab = {
        enable = true;
        statePath = "/mnt/gitlab";
        host = "git.codgician.me";
        reverseProxy.enable = true;
      };

      meshcommander = {
        enable = true;
        port = 3001;
        reverseProxy = {
          enable = true;
          domains = [ "amt.codgician.me" ];
        };
      };

      nixos-vscode-server.enable = true;

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

    system = {
      agenix.enable = true;
    };

    users = with lib.codgician; {
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
    codgician.codgi = {
      git.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "23.11";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

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
