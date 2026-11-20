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
  # The site's domain stays in nginx/sites.nix: lumine still proxies it with
  # no backend in the fleet, which the proxied-sites check allows only there.
  host = "127.0.0.1";
  port = 5001;
  defaultStateDir = "/var/lib/${serviceName}";

  environment =
    let
      artifactsPath =
        if cfg.backend == "nixpkgs" then cfg.artifactsDir else "/opt/app-root/src/artifacts";
      hfCachePath = if cfg.backend == "nixpkgs" then cfg.hfCacheDir else "/opt/app-root/src/hf-cache";
    in
    {
      # If artifactsDir is set, use it for flat-format models (org--model/)
      # If not set, explicitly unset to force HuggingFace standard loading
      DOCLING_SERVE_ARTIFACTS_PATH = if cfg.artifactsDir != null then artifactsPath else "";
      # HuggingFace hub cache for models in HF cache format (models--org--model/snapshots/...)
      HF_HUB_CACHE = lib.mkIf (cfg.hfCacheDir != null) hfCachePath;
      DOCLING_SERVE_ENABLE_UI = "true";
      DOCLING_SERVE_ENABLE_REMOTE_SERVICES = "true";
      DOCLING_SERVE_ALLOW_EXTERNAL_PLUGINS = "true";
      DOCLING_SERVE_SINGLE_USE_RESULTS = "true";
      DOCLING_SERVE_MAX_SYNC_WAIT = "1200"; # 20 minutes
      DOCLING_SERVE_RESULT_REMOVAL_DELAY = "600"; # 10 minutes
      DOCLING_DEVICE = if cfg.cuda then "cuda:0" else "cpu";
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

    cuda = lib.mkOption {
      type = types.bool;
      default = config.hardware.nvidia-container-toolkit.enable;
      defaultText = lib.literalExpression "config.hardware.nvidia-container-toolkit.enable";
      description = "Enable CUDA support for ${serviceName}.";
    };

    package = lib.mkPackageOption pkgs "docling-serve" {
      extraDescription = "Used by the `nixpkgs` backend.";
    };

    image = lib.mkOption {
      type = types.str;
      default =
        if cfg.cuda then
          "ghcr.io/docling-project/docling-serve-cu130:main"
        else
          "ghcr.io/docling-project/docling-serve:latest";
      defaultText = lib.literalExpression ''
        if cuda then "ghcr.io/docling-project/docling-serve-cu130:main"
        else "ghcr.io/docling-project/docling-serve:latest"
      '';
      description = "Container image used by the `container` backend.";
    };

    artifactsDir = lib.mkOption {
      type = with types; nullOr path;
      default = null;
      description = "Directory for pre-downloaded models in flat format (org--model/). If set, DOCLING_SERVE_ARTIFACTS_PATH will point here.";
    };

    hfCacheDir = lib.mkOption {
      type = with types; nullOr path;
      default = null;
      description = "HuggingFace hub cache directory for models in HF cache format. Required for VLM pipeline.";
    };

    stateDir = lib.mkOption {
      type = types.path;
      default = defaultStateDir;
      description = "Directory for ${serviceName} to store state data.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      codgician.services.nginx.reverseProxies.${serviceName}.proxyPass =
        "http://${host}:${builtins.toString port}";

      # Persist state directory (only when using default location)
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.stateDir == defaultStateDir) [
        {
          type = "directory";
          path = cfg.stateDir;
        }
      ];
    })

    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs") {
      services.docling-serve = {
        enable = true;
        inherit host port;
        inherit (cfg) stateDir;

        # Enable optional features
        package = cfg.package.override {
          withTesserocr = true;
          withRapidocr = true;
          withUI = true;
        };

        inherit environment;
      };

      systemd.services.docling-serve.serviceConfig = {
        ReadWritePaths =
          with cfg;
          (
            [ stateDir ]
            ++ lib.optional (artifactsDir != null) artifactsDir
            ++ lib.optional (hfCacheDir != null) hfCacheDir
          );

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

      # Ensure state directory exists (for custom paths)
      systemd.tmpfiles.rules = lib.mkIf (cfg.stateDir != defaultStateDir) [
        "d ${cfg.stateDir} 0750 docling-serve docling-serve -"
      ];
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
          inherit (cfg) image;
          volumes =
            lib.optionals cfg.cuda [
              "${ldSoConfFile}:/etc/ld.so.conf.d/00-system-libs.conf:ro"
            ]
            ++ [ "${cfg.stateDir}:/var/lib/docling-serve:U" ]
            ++ lib.optional (cfg.artifactsDir != null) "${cfg.artifactsDir}:/opt/app-root/src/artifacts:U"
            ++ lib.optional (cfg.hfCacheDir != null) "${cfg.hfCacheDir}:/opt/app-root/src/hf-cache:U";
          inherit environment;
          extraOptions = [
            "--pull=newer"
            "--net=host"
          ]
          ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
          cmd = [
            "docling-serve"
            "run"
            "--port"
            "${builtins.toString port}"
            "--host"
            host
          ];
        };
    })
  ];
}
