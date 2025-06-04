{
  config,
  lib,
  pkgs,
  ...
}:
{

  # My settings
  codgician = {
    containers = {
      comfyui = {
        enable = true;
        dataDir = "/xpool/appdata/comfyui";
        modelDir = "/xpool/llm/comfyui";
        reverseProxy = {
          enable = true;
          domains = [ "vanarana.codgician.me" ];
        };
      };

      fish-speech = {
        enable = true;
        dataDir = "/xpool/llm/fish-speech";
      };

      mcpo = {
        enable = true;
        dataDir = "/xpool/appdata/mcpo";
      };
    };

    services = {
      postgresql = {
        enable = true;
        dataDir = "/opool/postgres";
        zfsOptimizations = true;
      };

      nixos-vscode-server.enable = true;

      # Chat
      dendrite = {
        enable = true;
        domain = "matrix.codgician.me";
        dataPath = "/xpool/appdata/dendrite";
        reverseProxy = {
          enable = true;
          elementWeb = true;
        };
      };

      # LLM
      docling-serve = {
        enable = true;
        stateDir = "/xpool/appdata/docling-serve";
      };

      litellm.enable = true;
      ollama = {
        enable = true;
        acceleration = "cuda";
        modelDir = "/xpool/llm/ollama/models";
        loadModels = [
          "hf.co/unsloth/Qwen3-30B-A3B-GGUF:Q5_K_M"
          "hf.co/unsloth/Qwen3-32B-GGUF:Q5_K_M"
          "hf.co/unsloth/gemma-3-27b-it-qat-GGUF:Q4_K_M"
        ];
      };

      open-webui = {
        enable = true;
        # Use customized package
        package = pkgs.open-webui-akasha;
        database = "postgresql";
        stateDir = "/xpool/appdata/open-webui";
        reverseProxy = rec {
          enable = true;
          domains = [ "akasha.codgician.me" ];
          appIcon =
            (pkgs.fetchurl {
              url = "https://media.githubusercontent.com/media/codgician/assets/465dc48eabca23c08f1e07ba8b0cf07fd7cf53d6/images/akasha/logo.png";
              sha256 = "sha256-aXa2So5dcthDY8B1UXvfu4Ym8RSTAmR+XWPRokVC9oA=";
            }).outPath;
          favicon =
            (pkgs.fetchurl {
              url = "https://media.githubusercontent.com/media/codgician/assets/465dc48eabca23c08f1e07ba8b0cf07fd7cf53d6/images/akasha/logo-round.png";
              sha256 = "sha256-qty11SyWzNgxkOsUvy1BUI5NgydUdXN1V6p7FvHhvTk=";
            }).outPath;
          splash = favicon;
        };
      };

      # File server
      samba = {
        enable = true;
        users = [
          "codgi"
          "smb"
        ];
        shares = {
          "lab" = {
            path = "/fpool/lab";
            browsable = "yes";
            writeable = "yes";
            "force user" = "codgi";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0644";
            "directory mask" = "0755";
          };

          "media" = {
            path = "/fpool/media";
            browsable = "yes";
            writeable = "yes";
            "force user" = "codgi";
            "read only" = "no";
            "guest ok" = "yes";
            "create mask" = "0644";
            "directory mask" = "0755";
          };

          "timac" = {
            path = "/fpool/timac/";
            "valid users" = "codgi";
            public = "no";
            writeable = "yes";
            "force user" = "codgi";
            "guest ok" = "no";
            "fruit:time machine" = "yes";
            "fruit:time machine max size" = "1T";
          };
        };
      };

      jellyfin = {
        enable = true;
        dataDir = "/xpool/appdata/jellyfin";
        reverseProxy = {
          enable = true;
          domains = [ "fin.codgician.me" ];
        };
      };
    };

    system = {
      auto-upgrade.enable = true;
      impermanence = {
        enable = true;
        path = "/persist";
      };
      secure-boot.enable = true;
      nix.useCnMirror = true;
    };

    virtualization.podman.enable = true;

    users = with lib.codgician; {
      codgi = {
        enable = true;
        hashedPasswordAgeFile = getAgeSecretPathFromName "codgi-hashed-password";
        passwordAgeFile = getAgeSecretPathFromName "codgi-password";
        extraGroups = [
          "wheel"
          "podman"
        ];
      };

      smb = {
        enable = true;
        createHome = false;
        hashedPasswordAgeFile = getAgeSecretPathFromName "smb-hashed-password";
        passwordAgeFile = getAgeSecretPathFromName "smb-password";
      };
    };
  };

  # Home manager
  home-manager.users.codgi =
    { ... }:
    {
      codgician.codgi = {
        dev.nix.enable = true;
        git.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.05";
      home.packages = with pkgs; [
        httplz
        screen
        nur.repos.codgician.gddr6
      ];
    };

  # Use systemd-boot boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Allow RAID-1 esp boot
  boot.swraid = {
    enable = true;
    mdadmConf = "MAILADDR codgi";
  };

  # ZFS configurations
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = true;
    expandOnBoot = "all";
    trim.enable = true;
  };

  networking.hostId = "a7f3fe2e";

  # TPM
  security.tpm2 = {
    enable = true;
    abrmd.enable = true;
    pkcs11.enable = true;
  };

  # Firmware updates
  services.fwupd.enable = true;

  # Global packages
  environment.systemPackages =
    (with pkgs; [
      lm_sensors
      smartmontools
      pciutils
      nvme-cli
      usbutils
      ethtool
      sysstat
      powertop
      nvtopPackages.nvidia
      libhugetlbfs
    ])
    ++ (with config.boot.kernelPackages; [
      turbostat
    ]);

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
  system.stateVersion = "25.05"; # Did you read the comment?
}
