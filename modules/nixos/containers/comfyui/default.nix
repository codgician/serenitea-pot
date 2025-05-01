{ config, lib, ... }:
let
  cfg = config.codgician.containers.comfyui;
  types = lib.types;
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
    reverseProxy = {
      enable = lib.mkEnableOption "Reverse proxy for comfyui.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [
          "example.com"
          "example.org"
        ];
        default = [ ];
        description = ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://127.0.0.1:${builtins.toString cfg.port}";
        defaultText = ''http://127.0.0.1:$\{toString config.codgician.containers.comfyui.port}'';
        description = ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
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
            "--log-level=debug"
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
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.comfyui = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
          };
        };
      };
    })
  ];
}
