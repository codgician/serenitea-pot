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

  environment = {
    DOCLING_SERVE_ARTIFACTS_PATH = lib.mkIf (
      cfg.artifactsDir != null && cfg.backend == "nixpkgs"
    ) cfg.artifactsDir;
    DOCLING_SERVE_ENABLE_UI = "true";
    DOCLING_SERVE_ENABLE_REMOTE_SERVICES = "true";
    DOCLING_SERVE_ALLOW_EXTERNAL_PLUGINS = "true";
    DOCLING_SERVE_SINGLE_USE_RESULTS = "true";
    DOCLING_SERVE_MAX_SYNC_WAIT = "1200"; # 20 minutes
    DOCLING_SERVE_RESULT_REMOVAL_DELAY = "600"; # 10 minutes
    DOCLING_DEVICE = "cuda:0";
  };
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption serviceName;

    backend = lib.mkOption {
      type = lib.types.enum [
        "nixpkgs"
        "container"
      ];
      default = "nixpkgs";
      description = ''
        Backend to use for deploying ${serviceName}.
      '';
    };

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
    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs") {
      services.docling-serve = {
        enable = true;
        inherit (cfg) host port stateDir;

        # Enable optional features
        package = cfg.package.override {
          withTesserocr = true;
          withRapidocr = true;
          withUI = true;
        };

        inherit environment;
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

    # Container backend
    (lib.mkIf (cfg.enable && cfg.backend == "container") {
      virtualisation.oci-containers.containers.docling-serve =
        let
          # See: https://github.com/llm-d/llm-d/issues/117
          ldSoConfFile = pkgs.writeText "00-system-libs.conf" ''
            /lib64
            /usr/lib64
          '';
        in
        {
          autoStart = true;
          image =
            if config.hardware.nvidia-container-toolkit.enable then
              "ghcr.io/docling-project/docling-serve-cu128:latest"
            else
              "ghcr.io/docling-project/docling-serve:latest";
          volumes =
            lib.optionals config.hardware.nvidia-container-toolkit.enable [
              "${ldSoConfFile}:/etc/ld.so.conf.d/00-system-libs.conf:ro"
            ]
            ++ lib.optional (
              cfg.artifactsDir != null
            ) "${cfg.artifactsDir}:/opt/app-root/src/.cache/docling/models:rw";
          ports = [ "${builtins.toString cfg.port}:5001" ];
          inherit environment;
          extraOptions = [
            "--pull=newer"
            "--net=host"
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
