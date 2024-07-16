{ config, lib, pkgs, ... }: {

  # My settings
  codgician = {
    services = rec {
      nginx.openFirewall = true;

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

      rustdesk-server.enable = true;

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
      auto-upgrade.enable = true;
      common.enable = true;
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

    home.stateVersion = "24.05";
    home.packages = with pkgs; [ httplz iperf3 screen ];
  };

  # Global packages
  environment.systemPackages = with pkgs; [ ];

  # Getty
  services.getty.autologinUser = "codgi";

  # Firewall
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
