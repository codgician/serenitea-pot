{ config, lib, ... }:
let
  serviceName = "fish-speech";
  inherit (lib) types;
  cfg = config.codgician.containers.${serviceName};
in
{
  options.codgician.containers.${serviceName} = {
    enable = lib.mkEnableOption "${serviceName} container.";

    port = lib.mkOption {
      type = types.port;
      default = 8125;
      description = "Port for ${serviceName} to listen on.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = "Data directory for ${serviceName}.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://127.0.0.1:${toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.containers.${serviceName}; http://127.0.0.1:$\{toString port}'';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.${serviceName} = {
        autoStart = true;
        image = "docker.io/fishaudio/fish-speech:latest";
        volumes = [ "${cfg.dataDir}/reference:/opt/fish-speech/reference" ];
        extraOptions =
          [
            "--pull=newer"
            "--net=host"
          ]
          ++ lib.optionals config.hardware.nvidia-container-toolkit.enable [ "--device=nvidia.com/gpu=all" ];
        cmd = [
          "python"
          "tools/api_server.py"
          "--listen"
          "127.0.0.1:${builtins.toString cfg.port}"
        ];
      };

      virtualisation.podman.enable = true;
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
