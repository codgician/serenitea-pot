{ config, lib, ... }:
let
  serviceName = "fish-speech";
  inherit (lib) types;
  cfg = config.codgician.services.${serviceName};
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
      default = 8125;
      description = "Port for ${serviceName} to listen on.";
    };

    referencesDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}/references";
      description = "Directory for references.";
    };

    checkpointsDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}/checkpoints";
      description = "Directory for checkpoints.";
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
        image = "docker.io/fishaudio/fish-speech:webui-${if cfg.cuda then "cuda" else "cpu"}";
        volumes = [
          "${cfg.referencesDir}:/app/references:U"
          "${cfg.checkpointsDir}:/app/checkpoints:U"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
        cmd = [
          "python"
          "tools/api_server.py"
          "--compile"
          "--listen"
          "${cfg.host}:${builtins.toString cfg.port}"
        ];
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
