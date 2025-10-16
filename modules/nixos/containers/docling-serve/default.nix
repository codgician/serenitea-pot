{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "docling-serve";
  inherit (lib) types;
  cfg = config.codgician.containers.${serviceName};

  # See: https://github.com/llm-d/llm-d/issues/117
  ldSoConfFile = pkgs.writeText "00-system-libs.conf" ''
    /lib64
    /usr/lib64
    /lib/x86_64-linux-gnu
    /usr/lib/x86_64-linux-gnu
  '';
in
{
  options.codgician.containers.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} container.";

    host = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host for ${serviceName} to listen on.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 5001;
      description = "Port for ${serviceName} to listen on.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.containers.${serviceName}; http://$\{host}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image =
          if config.hardware.nvidia-container-toolkit.enable then
            "ghcr.io/docling-project/docling-serve-cu128:latest"
          else
            "ghcr.io/docling-project/docling-serve:latest";
        volumes = lib.optionals config.hardware.nvidia-container-toolkit.enable [
          "${ldSoConfFile}:/etc/ld.so.conf.d/00-system-libs.conf:ro"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "-e"
          "DOCLING_SERVE_ENABLE_UI=1"
        ]
        ++ lib.optionals config.hardware.nvidia-container-toolkit.enable [ "--device=nvidia.com/gpu=all" ];
      };

      virtualisation.podman.enable = true;
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
