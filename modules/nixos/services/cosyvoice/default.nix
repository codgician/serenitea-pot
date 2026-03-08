{ config, lib, ... }:
let
  serviceName = "cosyvoice";
  inherit (lib) types;
  cfg = config.codgician.services.${serviceName};
  defaultVoicesDir = "/var/lib/${serviceName}/voices";
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} service.";

    backend = lib.mkOption {
      type = types.enum [ "container" ];
      default = "container";
      description = "Backend to use for deploying ${serviceName}.";
    };

    cuda = lib.mkOption {
      type = types.bool;
      default = config.hardware.nvidia-container-toolkit.enable;
      defaultText = "config.hardware.nvidia-container-toolkit.enable";
      description = "Enable CUDA support for ${serviceName}.";
    };

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for ${serviceName} to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8127;
      description = "Port for ${serviceName} to listen on.";
    };

    image = lib.mkOption {
      type = types.str;
      default = "docker.io/neosun/cosyvoice:latest";
      description = "Docker image to use for ${serviceName}.";
    };

    voicesDir = lib.mkOption {
      type = types.path;
      default = defaultVoicesDir;
      description = "Directory for custom voice references.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.backend == "container") {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = cfg.image;

        volumes = [
          "${cfg.voicesDir}:/data/voices:U"
        ];

        environment = {
          PORT = builtins.toString cfg.port;
        };

        extraOptions = [
          "--pull=newer"
          "--net=host"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
      };

      # Ensure data directories exist (for custom paths)
      systemd.tmpfiles.rules = lib.optional (
        cfg.voicesDir != defaultVoicesDir
      ) "d ${cfg.voicesDir} 0755 root root -";

      # Persist data directories (only when using default locations)
      codgician.system.impermanence.extraItems = lib.optional (cfg.voicesDir == defaultVoicesDir) {
        type = "directory";
        path = cfg.voicesDir;
      };
    })

    # Reverse proxy profile for API
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      };
    }
  ];
}
