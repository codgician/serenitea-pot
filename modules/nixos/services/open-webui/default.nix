{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "open-webui";
  cfg = config.codgician.services.open-webui;
  types = lib.types;
  ollamaEmbeddingModel = "hf.co/jinaai/jina-embeddings-v4-text-retrieval-GGUF:Q4_K_M";
  pgDbName = "open-webui";
  pgDbHost = "/run/postgresql";
in
{
  options.codgician.services.open-webui = {
    enable = lib.mkEnableOption serviceName;

    package = lib.mkPackageOption pkgs "open-webui" { };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Host for ${serviceName} to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3010;
      description = ''
        Port for ${serviceName} to listen on.
      '';
    };

    database = lib.mkOption {
      type = types.enum [
        "sqlite"
        "postgresql"
      ];
      default = "sqlite";
      example = "postgresql";
      description = "Database backend for open-webui.";
    };

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/open-webui";
      description = "Directory to store ${serviceName} data.";
    };

    openFirewall = lib.mkEnableOption "Open firewall for ${serviceName}";

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.open-webui; http://$\{host}:$\{toString port}'';
      extraOptions = {
        # Custom favicon
        favicon = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/favicon.png";
          description = "Custom favicon.png for open-webui.";
        };

        appIcon = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/app-icon.png";
          description = "Custom app icon for open-webui.";
        };

        # Custom splash
        splash = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          example = "/path/to/splash.png";
          description = "Custom splash.png for open-webui.";
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.open-webui = {
        enable = true;
        inherit (cfg)
          host
          port
          stateDir
          openFirewall
          package
          ;
        environmentFile = config.age.secrets.open-webui-env.path;
        environment = import ./environment.nix {
          inherit
            lib
            cfg
            ollamaEmbeddingModel
            pgDbHost
            pgDbName
            ;
          doclingServeCfg = config.codgician.services.docling-serve;
          litellmCfg = config.codgician.services.litellm;
          ollamaCfg = config.codgician.services.ollama;
          redisCfg = config.services.redis;
        };
      };

      # Add embedding model to ollama
      codgician.services.ollama.loadModels = [ ollamaEmbeddingModel ];

      systemd.services.open-webui.serviceConfig = {
        SupplementaryGroups = [
          # Ensure access to Redis
          config.services.redis.servers.open-webui.group
          # For ROCm
          "render"
        ];

        # Allow access to GPU
        DeviceAllow = [
          # CUDA
          # https://docs.nvidia.com/dgx/pdf/dgx-os-5-user-guide.pdf
          "char-nvidiactl"
          "char-nvidia-caps"
          "char-nvidia-frontend"
          "char-nvidia-uvm"
          # ROCm
          "char-drm"
          "char-fb"
          "char-kfd"
          # WSL (Windows Subsystem for Linux)
          "/dev/dxg"
        ];

        # Disable dynamic user
        DynamicUser = lib.mkForce false;
        User = serviceName;
        Group = serviceName;
      };
    })

    # Persist
    (import ./persist.nix {
      inherit
        lib
        cfg
        options
        serviceName
        ;
    })

    # User
    (lib.codgician.mkServiceUserGroupLinux serviceName {
      uid = 2026;
      gid = 2026;
    })

    # PostgreSQL and Redis
    (import ./database.nix {
      inherit
        lib
        pkgs
        cfg
        pgDbName
        serviceName
        ;
      pgCfg = config.services.postgresql;
    })

    # Reverse proxy profile
    (import ./reverse-proxy.nix {
      inherit
        lib
        pkgs
        cfg
        serviceName
        ;
    })
  ];
}
