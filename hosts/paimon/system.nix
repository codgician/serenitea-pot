{ lib, pkgs, ... }:
{

  # My settings
  codgician = {
    services = {
      nginx.openFirewall = true;

      postgresql = {
        dataDir = "/mnt/postgres";
        zfsOptimizations = true;
      };

      calibre-web = {
        enable = false;
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
        users = [
          "codgi"
          "smb"
        ];
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
            "fruit:time machine max size" = "1TB";
            "vfs objects" = "catia fruit streams_xattr";
          };
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
    };

    users = with lib.codgician; {
      codgi = {
        enable = true;
        hashedPasswordAgeFile = secretsDir + "/codgiHashedPassword.age";
        passwordAgeFile = secretsDir + "/codgiPassword.age";
        extraGroups = [ "wheel" ];
      };
      smb = {
        enable = true;
        createHome = false;
        hashedPasswordAgeFile = secretsDir + "/smbHashedPassword.age";
        passwordAgeFile = secretsDir + "/smbPassword.age";
      };
    };
  };

  # Home manager
  home-manager.users.codgi =
    { config, ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "24.11";
      home.packages = with pkgs; [
        httplz
        screen
      ];
    };

  # Global packages
  environment.systemPackages = [ ];

  # Use networkd
  networking.useNetworkd = true;

  # Firewall
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
