{ config, lib, pkgs, ... }:
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
      description = lib.mdDoc ''
        Port for comfyui to listen on.
      '';
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/comfyui";
      description = lib.mdDoc ''
        Data directory for comfyui.
      '';
    };

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for comfyui.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.com" "example.org" ];
        default = [ ];
        description = lib.mdDoc ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://127.0.0.1:${toString cfg.port}";
        defaultText = ''http://127.0.0.1:$\{toString config.codgician.services.comfyui.port}'';
        description = lib.mdDoc ''
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
        image = "docker.io/yanwk/comfyui-boot:latest";
        ports = [ "${builtins.toString cfg.port}:8188" ];
        volumes = [ "${cfg.dataDir}:/home/runner" ];
        extraOptions = [ "--gpus=all" ];
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
