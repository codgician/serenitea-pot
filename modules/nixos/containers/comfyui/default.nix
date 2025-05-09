{ config, lib, ... }:
let
  serviceName = "comfyui";
  inherit (lib) types;
  cfg = config.codgician.containers.comfyui;
  uid = 2024;
in
{
  options.codgician.containers.comfyui = {
    enable = lib.mkEnableOption "ComfyUI container.";

    port = lib.mkOption {
      type = types.port;
      default = 8188;
      description = "Port for ComfyUI to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/comfyui";
      description = "Data directory for ComfyUI.";
    };

    modelDir = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Model directory for ComfyUI.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.containers.comfyui; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.comfyui = {
        autoStart = true;
        image = "docker.io/mmartial/comfyui-nvidia-docker:latest";
        ports = [ "${builtins.toString cfg.port}:8188" ];
        volumes = [
          "${cfg.dataDir}/basedir:/basedir"
          "${cfg.dataDir}/run:/comfy/mnt"
        ] ++ (lib.optional (cfg.modelDir != null) "${cfg.modelDir}:/comfy/mnt/ComfyUI/models");
        extraOptions =
          [
            "--pull=newer"
            "-e"
            "SECURITY_LEVEL=normal"
            "-e"
            "WANTED_UID=${builtins.toString uid}"
            "-e"
            "WANTED_GID=${builtins.toString uid}"
          ]
          ++ lib.optionals config.hardware.nvidia-container-toolkit.enable [ "--device=nvidia.com/gpu=all" ];
      };

      virtualisation.podman.enable = true;

      # Create user and group
      users.users.comfyui = {
        inherit uid;
        isSystemUser = true;
        group = "comfyui";
      };
      users.groups.comfyui = {
        gid = uid;
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
