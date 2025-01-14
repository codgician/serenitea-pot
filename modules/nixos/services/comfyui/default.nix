{ config, lib, ... }:
let
  cfg = config.codgician.services.comfyui;
  types = lib.types;
in
{
  options.codgician.services.comfyui = {
    enable = lib.mkEnableOption "Enable comfyui container.";

    port = lib.mkOption {
      type = types.port;
      default = 8188;
      description = ''
        Port for comfyui to listen on.
      '';
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/comfyui";
      description = ''
        Data directory for comfyui.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for comfyui.";

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
        defaultText = ''http://127.0.0.1:$\{toString config.codgician.services.comfyui.port}'';
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
        image = "docker.io/yanwk/comfyui-boot:cu124-megapak";
        ports = [ "${builtins.toString cfg.port}:8188" ];
        volumes = [ "${cfg.dataDir}:/root" ];
        extraOptions =
          [ "--log-level=debug" ]
          ++ lib.optionals config.hardware.nvidia-container-toolkit.enable [ "--device=nvidia.com/gpu=all" ];
      };

      virtualisation.podman.enable = true;
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
