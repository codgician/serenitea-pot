{ pkgs, ... }:
{
  codgician = {
    services = {
      nats.enable = true;

      mcpo = {
        enable = true;
        dataDir = "/xpool/appdata/mcpo";
      };

      open-terminal.enable = true;

      # Monitor
      prometheus.enable = true;
      grafana.enable = true;

      # Email
      postfix.enable = true;

      postgresql = {
        enable = true;
        dataDir = "/opool/postgres";
        zfsOptimizations = true;
      };

      redis.rootDir = "/opool/redis";

      authelia.instances.main.enable = true;

      # Chat
      matrix-tuwunel = {
        enable = true;
        dataPath = "/opool/tuwunel";
        zfsOptimizations = true;
      };

      sglang = {
        enable = true;
        cacheDir = "/xpool/llm/llm-cache";
        instances.qwen-chat = {
          model = "RadixArk/Qwen3.8-27B-NVFP4";
          host = "0.0.0.0";
          port = 8000;
          memFractionStatic = 0.95;
          environmentVariables = {
            SGLANG_DISABLE_SILU_FP4_QUANT_FUSION = "1";
            # Drop one mamba slot per running request (lazy: 4 -> 3).
            SGLANG_OPT_MAMBA_SKIP_DECODE_LOCK = "1";
          };
          extraArgs = [
            "--trust-remote-code"
            "--served-model-name"
            "Qwen3.8-27B"
            "--kv-cache-dtype"
            "fp8_e4m3"
            "--attention-backend"
            "flashinfer"
            "--fp4-gemm-backend"
            "marlin"
            # Each prefill chunk leaves a cached mamba checkpoint; larger chunks
            # keep checkpoints per prompt low enough for the HiCache mamba pool.
            "--chunked-prefill-size"
            "8192"
            # "--enable-mixed-chunk" # no-op when dflash enabled
            "--mamba-radix-cache-strategy"
            "extra_buffer_lazy"
            "--mamba-ssm-dtype"
            "bfloat16"
            "--context-length"
            "262144"
            "--max-total-tokens"
            "270336"
            "--cuda-graph-max-bs-prefill"
            "2048"
            "--cuda-graph-max-bs-decode"
            "6"
            "--max-running-requests"
            "6"
            # 6 running requests x 3 slots, plus 30 slots for cached prefixes.
            "--max-mamba-cache-size"
            "48"
            # Back the radix cache with pinned host RAM at 3x the device KV and
            # mamba pools (~38 GB, plus ~8 GB for the draft KV mirror), so
            # evicted prefixes reload over PCIe instead of being prefilled again.
            # A ratio scales each pool by capacity; --hicache-size splits by
            # device bytes, which overweights mamba via DFlash verify buffers.
            "--enable-hierarchical-cache"
            "--hicache-ratio"
            "3"
            # Admit queued requests with the longest cached prefix first, so
            # cache hits finish before their prefixes are evicted.
            "--schedule-policy"
            "lpm"
            "--reasoning-parser"
            "qwen3"
            "--tool-call-parser"
            "qwen3_coder"
            "--speculative-algorithm"
            "DFLASH"
            "--speculative-draft-model-path"
            "z-lab/Qwen3.8-27B-DFlash2"
            "--speculative-draft-model-quantization"
            "fp8"
            "--speculative-num-draft-tokens"
            "8"
          ];
        };
      };

      open-webui = {
        enable = true;
        stateDir = "/xpool/appdata/open-webui";
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

            # Time Machine reliability with SMB multichannel enabled.
            "strict sync" = "yes";
            "durable handles" = "yes";
            "kernel share modes" = "no";
            "posix locking" = "no";
            "case sensitive" = "true";
            "vfs objects" = "catia fruit streams_xattr";
          };
        };
      };

      gitlab = {
        enable = true;
        statePath = "/fpool/gitlab";
      };

      jellyfin = {
        enable = true;
        dataDir = "/xpool/appdata/jellyfin";
      };

      # Network lab
      gns3-server = {
        enable = true;
        dataDir = "/xpool/appdata/gns3";
      };
    };

    system = {
      auto-upgrade.enable = true;
      common.inChina = true;
      impermanence = {
        enable = true;
        wipeOnShutdown.zfs.enable = true;
      };
      secure-boot.enable = true;
    };

    virtualization.podman.enable = true;

    users = {
      codgi = {
        enable = true;
        passwordSecret = "codgi-password";
      };

      smb = {
        enable = true;
        hashedPasswordSecret = "smb-hashed-password";
        passwordSecret = "smb-password";
      };
    };
  };

  services.vscode-server.enable = true;

  home-manager.users.codgi = {
    codgician.codgi = {
      dev.nix.enable = true;
      codex.enable = true;
      git.enable = true;
      herdr.enable = true;
      mcp.enable = true;
      pi-coding-agent.enable = true;
      oh-my-pi.enable = true;
      pwsh.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    home.stateVersion = "26.05";

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

  system.stateVersion = "26.05";
}
