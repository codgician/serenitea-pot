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

    artifactsDir = lib.mkOption {
      type = with types; nullOr path;
      default = null;
      description = "Directory for ${serviceName} to store model artifacts.";
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
          withTesserocr = true;
          withRapidocr = true;
        };

        environment = {
          DOCLING_SERVE_ARTIFACTS_PATH = lib.mkIf (cfg.artifactsDir != null) cfg.artifactsDir;
          DOCLING_SERVE_ENABLE_UI = "true";
          DOCLING_SERVE_ENABLE_REMOTE_SERVICES = "true";
          DOCLING_SERVE_ALLOW_EXTERNAL_PLUGINS = "true";
          DOCLING_SERVE_SINGLE_USE_RESULTS = "true";
          DOCLING_SERVE_MAX_SYNC_WAIT = "1200"; # 20 minutes
          DOCLING_SERVE_RESULT_REMOVAL_DELAY = "600"; # 10 minutes
          DOCLING_DEVICE = "cuda:0";
        };
      };

      systemd.services.docling-serve.serviceConfig = {
        ReadWritePaths = with cfg; ([ stateDir ] ++ lib.optional (cfg.artifactsDir != null) artifactsDir);

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
