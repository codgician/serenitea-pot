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

  mkServeArgs =
    c:
    [
      "--host"
      "0.0.0.0"
      "--port"
      (toString c.port)
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
          example = "vllm/vllm-openai:latest-cu130";
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

        gpuMemoryUtilization = lib.mkOption {
          type = types.float;
          default = 0.9;
          description = ''
            Fraction of GPU memory this instance may reserve (0.0-1.0).
            Acts as the instance's GPU memory budget; when multiple
            instances share a GPU, the sum across instances must stay
            below 1.0.
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
        // c.environmentVariables;
        volumes = [
          "${cfg.cacheDir}:/root/.cache/huggingface:rw"
        ];
        ports = [
          "${c.host}:${toString c.port}:${toString c.port}"
        ];
        extraOptions = [
          "--pull=newer"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
        cmd = [ c.model ] ++ mkServeArgs c;
        environmentFiles = [ config.age.secrets.vllm-env.path ];
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

    cuda = lib.mkOption {
      type = types.bool;
      default = config.hardware.nvidia-container-toolkit.enable or false;
      description = "Enable CUDA/GPU support.";
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
      in
      map (k: {
        assertion = false;
        message =
          "codgician.services.vllm: multiple instances bind to ${k} "
          + "(${lib.concatMapStringsSep ", " (e: e.n) grouped.${k}}). "
          + "Containers use `--net=host`; every instance needs a unique (host, port) pair.";
      }) clashes;

    systemd.tmpfiles.rules = [ "d ${cfg.cacheDir} 0755 root root -" ];

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
