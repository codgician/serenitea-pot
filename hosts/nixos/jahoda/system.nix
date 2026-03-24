{
  lib,
  pkgs,
  ...
}:
{
  # My settings
  codgician = {
    services = {
      gnome.enable = true;
      nixos-vscode-server.enable = true;

      # Samba share for /code (dev-optimized for Windows 11 client over Thunderbolt)
      samba = {
        enable = true;
        users = [ "codgi" ];
        shares = {
          code = {
            path = "/code";
            browsable = "yes";
            writeable = "yes";
            "valid users" = "codgi";
            "read only" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";

            # Case sensitivity: critical for git/IDE performance
            # Prevents expensive directory scans for case-insensitive lookups
            "case sensitive" = "yes";
            "default case" = "lower";
            "preserve case" = "yes";
            "short preserve case" = "yes";

            # Oplocks: allow Windows to cache files locally
            "oplocks" = "yes";
            "level2 oplocks" = "yes";
            "kernel oplocks" = "yes";

            # Locking: relax for IDE/Git patterns
            "strict locking" = "no";
            "posix locking" = "no";

            # Symlinks: common in codebases
            "follow symlinks" = "yes";
            "wide links" = "yes";
            "allow insecure wide links" = "yes";

            # Veto noise files
            "veto files" = "/.DS_Store/Thumbs.db/desktop.ini/";
            "delete veto files" = "yes";
          };
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence.enable = true;
      secure-boot.enable = true;
    };

    users.codgi = with lib.codgician; {
      enable = true;
      hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
      passwordAgeFile = getAgeSecretPathFromName "codgi-password";
      extraGroups = [ "wheel" ];
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        codex = {
          enable = true;
          package = pkgs.codex-wrapped;
        };
        claude-code.enable = true;
        dev = {
          dotnet.enable = true;
          nix.enable = true;
        };
        opencode.enable = true;
        mcp.enable = true;
        git = {
          enable = true;
          directoryIdentities = {
            "/code/" = "work";
            "~/GitHub/" = "personal";
          };
        };
        gnome.favoriteApps = [
          "org.gnome.Nautilus.desktop"
          "microsoft-edge.desktop"
          "org.gnome.Console.desktop"
          "code.desktop"
        ];
        pwsh.enable = true;
        ssh.enable = true;
        vscode.enable = true;
        zsh.enable = true;
      };

      # Set Microsoft Edge as default browser
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "microsoft-edge.desktop";
          "x-scheme-handler/http" = "microsoft-edge.desktop";
          "x-scheme-handler/https" = "microsoft-edge.desktop";
          "x-scheme-handler/about" = "microsoft-edge.desktop";
          "x-scheme-handler/unknown" = "microsoft-edge.desktop";
        };
      };

      home.stateVersion = "25.11";
      home.packages =
        with pkgs;
        [
          cider-2
          virt-manager
        ]
        ++ (with pkgs.nur.repos.codgician; [
          nanokvm-usb
        ]);
    };

  # Enable Network Manager (leave thunderbolt0 to systemd-networkd)
  networking.networkmanager = {
    enable = true;
    unmanaged = [ "thunderbolt0" ];
  };
  networking.hostId = "357a80da";

  # Thunderbolt networking (point-to-point link to Windows PC)
  systemd.network = {
    enable = true;
    networks."40-thunderbolt" = {
      matchConfig.Name = "thunderbolt0";
      address = [ "172.16.0.1/24" ];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        LinkLocalAddressing = "no";
      };
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth = {
    enable = true;
    theme = "nixos-bgrt";
    themePackages = [ pkgs.nixos-bgrt-plymouth ];
  };

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # Enable pipewire.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.fwupd.enable = true;
  services.pulseaudio.enable = false;

  # Security
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Global packages
  environment.systemPackages = [ ];

  # Enable zram swap
  zramSwap.enable = true;

  # Increase inotify limits for IDEs (VS Code, JetBrains) over SMB
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 1024;
  };

  # Keyfile directory for secondary LUKS disk
  systemd.tmpfiles.rules = [
    "d /persist/keys 0700 root root -"
  ];

  # Enable nix-ld
  programs.nix-ld.enable = true;

  # Firewall
  networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
