{ config, lib, ... }:
let
  serviceName = "fish-speech";
  inherit (lib) types;
  cfg = config.codgician.services.${serviceName};

  # Helper function to generate container definitions
  mkFishContainer = { role, extraEnv ? {} }: {
    autoStart = true;
    image = "docker.io/fishaudio/fish-speech:${role}-${if cfg.cuda then "cuda" else "cpu"}";
    
    volumes = [
      "${cfg.referencesDir}:/app/references:U"
      "${cfg.checkpointsDir}:/app/checkpoints:U"
    ];

    environment = {
      COMPILE = if cfg.cuda then "1" else "0";
    } // extraEnv;

    extraOptions = [
      "--pull=newer"
      "--net=host"
    ] ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
  };
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

    gradio = {
      enable = lib.mkEnableOption "Enable Gradio interface for ${serviceName}.";
      port = lib.mkOption {
        type = types.port;
        default = 8126;
        description = "Port for Gradio interface to listen on.";
      };

      # Reverse proxy profile for nginx
      reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
        serviceName = "${serviceName}-gradio";
        defaultProxyPass = "http://127.0.0.1:${toString cfg.gradio.port}";
        defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://127.0.0.1:$\{toString gradio.port}'';
      };
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
      virtualisation.oci-containers.containers = {
        # 1. Main API Server Container
        ${serviceName} = mkFishContainer {
          role = "server";
          extraEnv = {
            API_SERVER_NAME = cfg.host;
            API_SERVER_PORT = builtins.toString cfg.port;
          };
        };
      } 
      # 2. Optional Gradio WebUI Container
      // (lib.optionalAttrs cfg.gradio.enable {
        "${serviceName}-webui" = mkFishContainer {
          role = "webui";
          extraEnv = {
            GRADIO_SERVER_NAME = cfg.host;
            GRADIO_SERVER_PORT = builtins.toString cfg.gradio.port;
          };
        };
      });
    })

    # Reverse proxy profile for API
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })

    # Reverse proxy profile for Gradio
    (lib.codgician.mkServiceReverseProxyConfig {
      serviceName = "${serviceName}-gradio";
      cfg = cfg.gradio;
    })
  ];
}