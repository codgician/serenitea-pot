{
  lib,
  pkgs,
  ...
}:
{

  # My settings
  codgician = {
    services = {
      comfyui = {
        enable = true;
        dataDir = "/xpool/appdata/comfyui";
        modelDir = "/xpool/llm/comfyui";
        userDir = "/xpool/appdata/comfyui-user";
        reverseProxy = {
          enable = true;
          domains = [ "vanarana.codgician.me" ];
          authelia = {
            enable = true;
            rules = [
              {
                groups = [ "vanarana" ];
                policy = "two_factor";
              }
            ];
          };
        };
      };
      mcpo = {
        enable = true;
        dataDir = "/xpool/appdata/mcpo";
      };

      open-terminal.enable = true;

      # Auth
      authelia.instances.main = {
        enable = true;
        sessionDomain = "codgician.me";
        domain = "auth.codgician.me";
        database = "postgresql";
        reverseProxy.enable = true;
      };

      # Monitor
      prometheus.enable = true;

      # Email
      postfix.enable = true;

      postgresql = {
        enable = true;
        dataDir = "/opool/postgres";
        zfsOptimizations = true;
      };

      nixos-vscode-server.enable = true;

      # Chat
      matrix-tuwunel = {
        enable = true;
        domain = "matrix.codgician.me";
        dataPath = "/opool/tuwunel";
        zfsOptimizations = true;
        reverseProxy = {
          enable = true;
          elementWeb = true;
        };
      };

      docling-serve = {
        enable = true;
        backend = "container";
        hfCacheDir = "/xpool/llm/docling-serve/hf-cache";
        reverseProxy = {
          enable = true;
          authelia = {
            enable = true;
            rules = [
              {
                groups = [ "vision" ];
                policy = "two_factor";
              }
            ];
          };
          domains = [ "vision.codgician.me" ];
        };
      };

      cosyvoice = {
        enable = true;
        voicesDir = "/xpool/llm/cosyvoice/voices";
        reverseProxy = {
          enable = true;
          authelia = {
            enable = true;
            rules = [
              {
                groups = [ "voice" ];
                policy = "two_factor";
              }
            ];
          };
          domains = [ "voice.codgician.me" ];
        };
      };

      mirofish = {
        enable = true;
        dataDir = "/xpool/llm/mirofish";
        reverseProxy = {
          enable = true;
          domains = [ "astrolabe.codgician.me" ];
          authelia = {
            enable = true;
            rules = [
              {
                groups = [ "astrolabe" ];
                policy = "two_factor";
              }
            ];
          };
        };
      };

      vllm = {
        enable = true;
        cuda = true;
        cacheDir = "/xpool/llm/vllm-cache";
        imageTag = "latest-cu130";

        instances = {
          qwen-chat = {
            model = "QuantTrio/Qwen3.5-35B-A3B-AWQ";
            port = 8000;
            gpuMemoryUtilization = 0.66;
            maxModelLen = 262144;
            maxNumSeqs = 8;
            quantization = "awq_marlin";
            kvCacheDtype = "fp8";
            maxNumBatchedTokens = 2096;
            reasoningParser = "qwen3";
            toolCallParser = "qwen3_coder";
            enablePrefixCaching = true;
            enableChunkedPrefill = true;
            trustRemoteCode = true;
            warmupOnStart = true;
            environmentVariables = {
              VLLM_USE_DEEP_GEMM = "0";
              VLLM_USE_FLASHINFER_MOE_FP16 = "1";
              VLLM_USE_FLASHINFER_SAMPLER = "0";
            };
            extraArgs = [ "--enable-expert-parallel" ];
          };

          embeddings = {
            model = "Qwen/Qwen3-Embedding-0.6B";
            port = 8001;
            gpuMemoryUtilization = 0.07;
            maxModelLen = 8192;
            maxNumSeqs = 64;
          };
        };
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

        # Use vLLM for embeddings (accepts 2560-d vectors, replacing existing 1536-d)
        embedding = {
          engine = "vllm";
          model = "Qwen/Qwen3-Embedding-0.6B";
          vllm.instance = "embeddings";
        };
      };

      # Monitoring
      grafana = {
        enable = true;
        reverseProxy = {
          enable = true;
          domains = [ "lumenstone.codgician.me" ];
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
            "fruit:time machine max size" = "2T";
          };
        };
      };

      gitlab = {
        enable = true;
        statePath = "/fpool/gitlab";
        host = "git.codgician.me";
        reverseProxy.enable = true;
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
        wipeOnShutdown.zfs = {
          enable = true;
          datasets = [ "zroot/root" ];
        };
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
        opencode.enable = true;
        mcp.enable = true;
        pwsh.enable = true;
        ssh.enable = true;
        zsh.enable = true;
      };

      home.stateVersion = "25.11";
      home.packages = with pkgs; [
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

  networking.hostId = "a7f3fe2e";

  # Firmware updates
  services.fwupd.enable = true;

  # Global packages
  environment.systemPackages = with pkgs; [
    authelia
    libhugetlbfs
  ];

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
  system.stateVersion = "25.11"; # Did you read the comment?
}
