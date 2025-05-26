{
  config,
  pkgs,
  lib,
  ...
}:
let
  serviceName = "docling-serve";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption serviceName;

    package = lib.mkPackageOption pkgs "docling-serve" { };

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

    stateDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/${serviceName}";
      description = "Directory for ${serviceName} to store state data.";
    };

    # Reverse proxy profile for nginx
    reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
      inherit serviceName;
      defaultProxyPass = "http://${cfg.host}:${builtins.toString cfg.port}";
      defaultProxyPassText = ''with config.codgician.services.${serviceName}; http://$\{host}:$\{builtins.toString port}'';
    };
  };

  config = lib.mkMerge [
    # docling-serve configurations
    (lib.mkIf cfg.enable {
      services.docling-serve = {
        enable = true;
        inherit (cfg) host port stateDir;

        # Enable optional features
        package = cfg.package.override {
          withUI = true;
          withTesserocr = true;
          withRapidocr = true;
          withCPU = true;
        };

        environment = {
          DOCLING_SERVE_ENABLE_UI = "true";
          DOCLING_DEVICE = "cuda";
        };
      };

      systemd.services.docling-serve.serviceConfig = {
        ReadWritePaths = [ cfg.stateDir ];

        # Allow access to GPU
        SupplementaryGroups = [ "render" ]; # For ROCm
        DeviceAllow = [
          # CUDA
          # https://docs.nvidia.com/dgx/pdf/dgx-os-5-user-guide.pdf
          "char-nvidiactl"
          "char-nvidia-caps"
          "char-nvidia-frontend"
          "char-nvidia-uvm"
          # ROCm
          "char-drm"
          "char-fb"
          "char-kfd"
          # WSL (Windows Subsystem for Linux)
          "/dev/dxg"
        ];
      };
    })

    # Reverse proxy profile
    (lib.codgician.mkServiceReverseProxyConfig {
      inherit serviceName cfg;
    })
  ];
}
