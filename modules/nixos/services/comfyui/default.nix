{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "comfyui";
  inherit (lib) types;
  cfg = config.codgician.services.comfyui;
  defaultDataDir = "/var/lib/comfyui";

  # See: https://github.com/llm-d/llm-d/issues/117
  ldSoConfFile = pkgs.writeText "00-system-libs.conf" ''
    /lib64
    /usr/lib64
  '';
in
{
  options.codgician.services.comfyui = {
    enable = lib.mkEnableOption "ComfyUI container.";

    imageTag = lib.mkOption {
      type = types.str;
      default = "cu128-slim";
      description = "Container image tag.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8188;
      description = "Port for ComfyUI to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = defaultDataDir;
      description = "Data directory for ComfyUI.";
    };

    modelDir = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Model directory for ComfyUI.";
    };

    userDir = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "User directory for ComfyUI.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.comfyui; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.comfyui = {
        autoStart = true;
        image = "docker.io/yanwk/comfyui-boot:${cfg.imageTag}";
        ports = [ "${builtins.toString cfg.port}:8188" ];
        volumes = [
          "${cfg.dataDir}:/root:rw"
          "${ldSoConfFile}:/etc/ld.so.conf.d/00-system-libs.conf:ro"
        ]
        ++ (lib.optional (cfg.modelDir != null) "${cfg.modelDir}:/root/ComfyUI/models:rw")
        ++ (lib.optional (cfg.userDir != null) "${cfg.userDir}:/storage-user:rw");
        extraOptions = [
          "--pull=newer"
        ]
        ++ lib.optionals config.hardware.nvidia-container-toolkit.enable [ "--device=nvidia.com/gpu=all" ];
      };

      virtualisation.podman.enable = true;

      # Ensure data directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != defaultDataDir) [
        "d ${cfg.dataDir} 0755 root root -"
      ];

      # Persist data directory (only when using default location)
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
        {
          type = "directory";
          path = cfg.dataDir;
        }
      ];
    })

    # Reverse proxy profile
    {
      codgician.services.nginx = lib.codgician.mkServiceReverseProxyConfig {
        inherit serviceName cfg;
      };
    }
  ];
}
