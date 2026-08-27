{
  config,
  lib,
  ...
}:
let
  serviceName = "sglang";
  cfg = config.codgician.services.sglang;
  inherit (lib) types;

  defaultCacheDir = "/var/lib/llm-cache";
  containerKernelConfigDir = "/sgl-workspace/sglang/python/sglang/kernels/ops/quantization/configs";
  containerAdaptiveSpeculativeConfigPath = "/tmp/sglang-adaptive-speculative.json";
  hasNvidia = config.hardware.nvidia-container-toolkit.enable or false;
  scrapeHost =
    host:
    if
      builtins.elem host [
        "0.0.0.0"
        "::"
      ]
    then
      "127.0.0.1"
    else
      host;
  dashboard = builtins.toFile "sglang-dashboard.json" (builtins.toJSON (import ./dashboard.nix));

  mkLaunchArgs =
    c:
    [
      "python3"
      "-m"
      "sglang.launch_server"
      "--model-path"
      c.model
      "--host"
      "0.0.0.0"
      "--port"
      (toString c.port)
    ]
    ++ lib.optionals (c.device == "cuda") [
      "--mem-fraction-static"
      (toString c.memFractionStatic)
    ]
    ++ lib.optional cfg.monitoring.enable "--enable-metrics"
    ++ lib.optionals (c.adaptiveSpeculativeConfig != null) [
      "--speculative-adaptive-config"
      containerAdaptiveSpeculativeConfigPath
    ]
    ++ c.extraArgs;

  instanceModule =
    { config, name, ... }:
    {
      options = {
        model = lib.mkOption {
          type = types.str;
          description = "ModelScope or Hugging Face model name, or a local model path.";
          example = "Qwen/Qwen3.8-27B-FP8";
        };

        image = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Per-instance image override. Null uses `cfg.image`.";
        };

        host = lib.mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Host-side bind address for the published port.";
        };

        port = lib.mkOption {
          type = types.port;
          default = 30000;
          description = "SGLang HTTP server port inside and outside the container.";
        };

        device = lib.mkOption {
          type = types.enum [
            "cuda"
            "cpu"
          ];
          default = if hasNvidia then "cuda" else "cpu";
          defaultText = lib.literalExpression ''if config.hardware.nvidia-container-toolkit.enable then "cuda" else "cpu"'';
          description = "Inference device. CUDA instances receive every NVIDIA GPU through CDI.";
        };

        memFractionStatic = lib.mkOption {
          type = types.float;
          default = 0.9;
          description = "Fraction of GPU memory reserved for model weights and the KV cache pool.";
        };

        useModelScope = lib.mkOption {
          type = types.bool;
          default = config.codgician.system.common.inChina;
          defaultText = lib.literalExpression "config.codgician.system.common.inChina";
          description = "Download models from ModelScope instead of Hugging Face.";
        };

        environmentVariables = lib.mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Environment variables for this instance.";
        };

        extraArgs = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional arguments passed to `sglang.launch_server`.";
          example = [
            "--kv-cache-dtype"
            "fp8_e4m3"
          ];
        };

        adaptiveSpeculativeConfig = lib.mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            JSON configuration for `--speculative-adaptive-config`. The file is
            mounted read-only inside the container when set.
          '';
        };

        kernelConfigDir = lib.mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Directory containing per-shape W8A8 kernel tuning configurations.
            The files must match the image's SGLang, Triton, CUDA, GPU, and
            quantization versions.
          '';
        };

        reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
          serviceName = "${serviceName}@${name}";
          defaultProxyPass = "http://${config.host}:${toString config.port}";
          defaultProxyPassText = "http://\${host}:\${port}";
        };
      };
    };

  mkContainer =
    name:
    let
      c = cfg.instances.${name};
    in
    {
      "${serviceName}-${name}" = {
        autoStart = true;
        image = if c.image != null then c.image else cfg.image;
        environment = {
          HF_HUB_DOWNLOAD_TIMEOUT = "600";
        }
        // lib.optionalAttrs c.useModelScope {
          SGLANG_USE_MODELSCOPE = "true";
        }
        // c.environmentVariables;
        volumes = [
          "${cfg.cacheDir}:/root/.cache:rw"
        ]
        ++ lib.optionals (c.kernelConfigDir != null) (
          map (
            file:
            let
              targetName = lib.replaceStrings [ "[128,128]" ] [ "[128, 128]" ] file;
            in
            "${c.kernelConfigDir}/${file}:${containerKernelConfigDir}/${targetName}:ro"
          ) (builtins.attrNames (builtins.readDir c.kernelConfigDir))
        )
        ++ lib.optionals (c.adaptiveSpeculativeConfig != null) [
          "${c.adaptiveSpeculativeConfig}:${containerAdaptiveSpeculativeConfigPath}:ro"
        ];
        ports = [ "${c.host}:${toString c.port}:${toString c.port}" ];
        extraOptions = [
          "--pull=newer"
          "--ipc=host"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals (c.device == "cuda") [ "--device=nvidia.com/gpu=all" ];
        cmd = mkLaunchArgs c;
      };
    };

  instances = builtins.attrNames cfg.instances;
  hasInstances = cfg.enable && cfg.instances != { };
in
{
  options.codgician.services.sglang = {
    enable = lib.mkEnableOption "SGLang inference server (container-based)";

    image = lib.mkOption {
      type = types.str;
      default = "lmsysorg/sglang:latest";
      description = "Default image ref for instances that do not override `image`.";
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = defaultCacheDir;
      description = "Shared model cache directory mounted at `/root/.cache`.";
    };

    monitoring.enable = lib.mkEnableOption "Prometheus scraping and the bundled Grafana dashboard";

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
      description = "SGLang server instances.";
    };
  };

  config = lib.mkIf hasInstances {
    assertions =
      let
        endpointPairs = map (name: {
          inherit name;
          key = "${cfg.instances.${name}.host}:${toString cfg.instances.${name}.port}";
        }) instances;
        grouped = lib.groupBy (entry: entry.key) endpointPairs;
        clashes = lib.filter (key: builtins.length grouped.${key} > 1) (builtins.attrNames grouped);
        cudaWithoutHost = lib.filter (name: cfg.instances.${name}.device == "cuda" && !hasNvidia) instances;
      in
      map (key: {
        assertion = false;
        message =
          "codgician.services.sglang: multiple instances bind to ${key} "
          + "(${lib.concatMapStringsSep ", " (entry: entry.name) grouped.${key}}).";
      }) clashes
      ++ map (name: {
        assertion = false;
        message = "codgician.services.sglang.instances.${name}.device is \"cuda\" but hardware.nvidia-container-toolkit is disabled.";
      }) cudaWithoutHost
      ++ [
        {
          assertion = !cfg.monitoring.enable || config.codgician.services.prometheus.enable;
          message = "codgician.services.sglang.monitoring requires codgician.services.prometheus.enable.";
        }
        {
          assertion = !cfg.monitoring.enable || config.codgician.services.grafana.enable;
          message = "codgician.services.sglang.monitoring requires codgician.services.grafana.enable.";
        }
      ];

    systemd.tmpfiles.rules = [ "d ${cfg.cacheDir} 0755 root root -" ];

    codgician.system.impermanence.extraItems = lib.optional (cfg.cacheDir == defaultCacheDir) {
      type = "directory";
      path = cfg.cacheDir;
    };

    codgician.services.prometheus.scrapeConfigs.extraConfigs = lib.optional cfg.monitoring.enable {
      job_name = serviceName;
      scrape_interval = "2s";
      metrics_path = "/metrics";
      static_configs = map (name: {
        targets = [ "${scrapeHost cfg.instances.${name}.host}:${toString cfg.instances.${name}.port}" ];
        labels = {
          instance = config.networking.hostName;
          service = name;
        };
      }) instances;
    };

    codgician.services.grafana.provision.prometheus.timeInterval = lib.mkIf cfg.monitoring.enable "2s";

    codgician.services.grafana.provision.dashboards = lib.optional cfg.monitoring.enable {
      path = dashboard;
    };

    virtualisation.oci-containers.containers = lib.mkMerge (map mkContainer instances);

    codgician.services.nginx = lib.mkMerge (
      map (
        name:
        lib.codgician.mkServiceReverseProxyConfig {
          serviceName = "${serviceName}@${name}";
          cfg = cfg.instances.${name};
        }
      ) instances
    );
  };
}
