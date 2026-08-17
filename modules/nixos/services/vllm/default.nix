{
  config,
  lib,
  ...
}:
let
  serviceName = "vllm";
  cfg = config.codgician.services.vllm;
  inherit (lib) types;

  defaultCacheDir = "/var/lib/vllm-cache";
  containerKernelConfigDir = "/etc/vllm/fp8-kernel-configs";
  containerKernelConfigEntrypoint = "/etc/vllm/load-fp8-kernel-configs.sh";
  kernelConfigEntrypoint = builtins.toFile "load-vllm-fp8-kernel-configs.sh" ''
    set -eu

    config_dir="$(
      python3 -c 'from importlib.util import find_spec; from pathlib import Path; spec = find_spec("vllm"); print(Path(next(iter(spec.submodule_search_locations))) / "model_executor/layers/quantization/utils/configs")'
    )"
    cp ${containerKernelConfigDir}/*.json "$config_dir"/
    exec vllm serve "$@"
  '';
  hasNvidia = config.hardware.nvidia-container-toolkit.enable or false;

  mkServeArgs =
    c:
    [
      "--host"
      "0.0.0.0"
      "--port"
      (toString c.port)
    ]
    ++ lib.optionals (c.device == "cuda") [
      "--gpu-memory-utilization"
      (toString c.gpuMemoryUtilization)
    ]
    ++ c.extraArgs;

  instanceModule =
    { config, name, ... }:
    {
      options = {
        model = lib.mkOption {
          type = types.str;
          description = "HuggingFace model name or path to serve.";
          example = "Qwen/Qwen3.5-35B-A3B-AWQ";
        };

        image = lib.mkOption {
          type = types.nullOr types.str;
          default = "vllm/vllm-openai:latest";
          description = ''
            Per-instance image override. Null uses `cfg.image`.
          '';
        };

        host = lib.mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = ''
            Host-side bind address for the published port. Docker maps the
            container's port onto this address on the host.
          '';
        };

        port = lib.mkOption {
          type = types.port;
          default = 8000;
          description = ''
            Port vLLM listens on. Used as both the container-internal port
            and the host-side mapped port.
          '';
        };

        device = lib.mkOption {
          type = types.enum [
            "cuda"
            "cpu"
          ];
          default = if hasNvidia then "cuda" else "cpu";
          defaultText = lib.literalExpression ''if config.hardware.nvidia-container-toolkit.enable then "cuda" else "cpu"'';
          description = ''
            Inference device for this instance.
            `"cuda"` mounts the NVIDIA GPU and passes `--gpu-memory-utilization`.
            `"cpu"` leaves the GPU unmounted so vLLM's platform auto-detect
            selects CPU. Use a CPU image (e.g. `vllm/vllm-openai-cpu`).
          '';
        };

        gpuMemoryUtilization = lib.mkOption {
          type = types.float;
          default = 0.9;
          description = ''
            Fraction of GPU memory this instance may reserve (0.0-1.0).
            Ignored when `device = "cpu"`. When multiple CUDA instances
            share a GPU, the sum across those instances must stay below 1.0.
          '';
        };

        environmentVariables = lib.mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Environment variables for this instance.";
        };

        extraArgs = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Additional vLLM serve arguments. Model-specific tuning flags
            (e.g. `--max-model-len`, `--quantization`,
            `--tensor-parallel-size`, `--dtype`, `--kv-cache-dtype`,
            `--enable-prefix-caching`, `--trust-remote-code`,
            `--tool-call-parser`, `--reasoning-parser`, etc.) should be
            passed here.
          '';
          example = [
            "--max-model-len"
            "8192"
          ];
        };

        kernelConfigDir = lib.mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Directory of per-shape vLLM kernel tuning configurations to mount
            read-only into the container. Configurations must match the image's
            vLLM, Triton, CUDA, GPU, quantization, and tensor-parallel setup.
          '';
        };

        reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
          serviceName = "${serviceName}@${name}";
          defaultProxyPass = "http://${config.host}:${toString config.port}";
          defaultProxyPassText = "http://\${host}:\${port}";
        };
      };
    };

  mkContainer = name: {
    "${serviceName}-${name}" =
      let
        c = cfg.instances.${name};
      in
      {
        autoStart = true;
        image = if c.image != null then c.image else cfg.image;
        environment = {
          VLLM_NO_USAGE_STATS = "1";
          HF_HUB_DOWNLOAD_TIMEOUT = "600";
        }
        // lib.optionalAttrs config.codgician.system.common.inChina {
          # Download models from ModelScope instead of Hugging Face if host in China
          VLLM_USE_MODELSCOPE = "True";
        }
        // c.environmentVariables;
        volumes = [
          "${cfg.cacheDir}:/root/.cache:rw"
        ]
        ++ lib.optionals (c.kernelConfigDir != null) [
          "${c.kernelConfigDir}:${containerKernelConfigDir}:ro"
          "${kernelConfigEntrypoint}:${containerKernelConfigEntrypoint}:ro"
        ];
        ports = [
          "${c.host}:${toString c.port}:${toString c.port}"
        ];
        extraOptions = [
          "--pull=newer"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals (c.device == "cuda") [ "--device=nvidia.com/gpu=all" ]
        ++ lib.optional (c.kernelConfigDir != null) "--entrypoint=/bin/sh";
        cmd =
          lib.optional (c.kernelConfigDir != null) containerKernelConfigEntrypoint
          ++ [ c.model ]
          ++ mkServeArgs c;
        environmentFiles = [ config.codgician.secrets.templates."vllm-env".path ];
      };
  };

  instances = builtins.attrNames cfg.instances;
  hasInstances = cfg.enable && cfg.instances != { };
in
{
  options.codgician.services.vllm = {
    enable = lib.mkEnableOption "vLLM inference server (container-based)";

    image = lib.mkOption {
      type = types.str;
      default = "vllm/vllm-openai:latest";
      example = "vllm/vllm-openai:latest-cu130";
      description = ''
        Default image ref for instances that don't set their own `image`.
      '';
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = defaultCacheDir;
      description = "Model cache directory (mounted into container).";
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
      description = "vLLM server instances.";
    };
  };

  config = lib.mkIf hasInstances {
    assertions =
      let
        endpointPairs = map (n: {
          inherit n;
          key = "${cfg.instances.${n}.host}:${toString cfg.instances.${n}.port}";
        }) instances;
        grouped = lib.groupBy (e: e.key) endpointPairs;
        clashes = lib.filter (k: builtins.length grouped.${k} > 1) (builtins.attrNames grouped);
        cudaWithoutHost = lib.filter (n: cfg.instances.${n}.device == "cuda" && !hasNvidia) instances;
      in
      map (k: {
        assertion = false;
        message =
          "codgician.services.vllm: multiple instances bind to ${k} "
          + "(${lib.concatMapStringsSep ", " (e: e.n) grouped.${k}}). "
          + "Containers use `--net=host`; every instance needs a unique (host, port) pair.";
      }) clashes
      ++ map (n: {
        assertion = false;
        message = "codgician.services.vllm.instances.${n}.device is \"cuda\" but hardware.nvidia-container-toolkit is disabled.";
      }) cudaWithoutHost;

    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root -"
    ];

    codgician.system.impermanence.extraItems = lib.optional (cfg.cacheDir == defaultCacheDir) {
      type = "directory";
      path = cfg.cacheDir;
    };

    virtualisation.oci-containers.containers = lib.mkMerge (map mkContainer instances);

    codgician.services.nginx = lib.mkMerge (
      map (
        i:
        lib.codgician.mkServiceReverseProxyConfig {
          serviceName = "${serviceName}@${i}";
          cfg = cfg.instances.${i};
        }
      ) instances
    );
  };
}
