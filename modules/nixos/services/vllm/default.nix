{
  config,
  lib,
  pkgs,
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
      c.host
      "--port"
      (toString c.port)
      "--download-dir"
      "/root/.cache/huggingface"
    ]
    ++ lib.optionals (c.maxModelLen != null) [
      "--max-model-len"
      (toString c.maxModelLen)
    ]
    ++ lib.optionals (c.quantization != null) [
      "--quantization"
      c.quantization
    ]
    ++ lib.optionals (c.tensorParallelSize != 1) [
      "--tensor-parallel-size"
      (toString c.tensorParallelSize)
    ]
    ++ lib.optionals (c.gpuMemoryUtilization != 0.9) [
      "--gpu-memory-utilization"
      (toString c.gpuMemoryUtilization)
    ]
    ++ lib.optionals (c.dtype != "auto") [
      "--dtype"
      c.dtype
    ]
    ++ lib.optionals (c.kvCacheDtype != "auto") [
      "--kv-cache-dtype"
      c.kvCacheDtype
    ]
    ++ lib.optionals (c.maxNumSeqs != 256) [
      "--max-num-seqs"
      (toString c.maxNumSeqs)
    ]
    ++ lib.optionals (c.maxNumBatchedTokens != null) [
      "--max-num-batched-tokens"
      (toString c.maxNumBatchedTokens)
    ]
    ++ lib.optionals c.enablePrefixCaching [ "--enable-prefix-caching" ]
    ++ lib.optionals c.enableChunkedPrefill [ "--enable-chunked-prefill" ]
    ++ lib.optionals c.trustRemoteCode [ "--trust-remote-code" ]
    ++ lib.optionals c.disableLogStats [ "--disable-log-stats" ]
    ++ lib.optionals (c.servedModelName != null) [
      "--served-model-name"
      c.servedModelName
    ]
    ++ lib.optionals (c.toolCallParser != null) [
      "--enable-auto-tool-choice"
      "--tool-call-parser"
      c.toolCallParser
    ]
    ++ lib.optionals (c.reasoningParser != null) [
      "--reasoning-parser"
      c.reasoningParser
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
          default = null;
          example = "vllm/vllm-openai:latest-cu130";
          description = ''
            Per-instance image override. Null uses `cfg.image`.
          '';
        };

        host = lib.mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Host address for vLLM to listen on.";
        };

        port = lib.mkOption {
          type = types.port;
          default = 8000;
          description = "Port for vLLM to listen on.";
        };

        gpuMemoryUtilization = lib.mkOption {
          type = types.float;
          default = 0.9;
          description = "Fraction of GPU memory to use (0.0-1.0).";
        };

        dtype = lib.mkOption {
          type = types.str;
          default = "auto";
          description = "Data type for model weights (auto, float16, bfloat16).";
        };

        kvCacheDtype = lib.mkOption {
          type = types.enum [
            "auto"
            "fp8"
            "fp8_e5m2"
            "fp8_e4m3"
          ];
          default = "auto";
          description = "KV cache data type. fp8 reduces memory ~50%.";
        };

        maxModelLen = lib.mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum sequence length.";
        };

        maxNumSeqs = lib.mkOption {
          type = types.int;
          default = 256;
          description = "Maximum concurrent sequences.";
        };

        maxNumBatchedTokens = lib.mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Max tokens per batch (required for Mamba cache alignment).";
        };

        quantization = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Quantization method (e.g., awq, awq_marlin, gptq, gptq_marlin, fp8).";
        };

        tensorParallelSize = lib.mkOption {
          type = types.int;
          default = 1;
          description = "Number of GPUs for tensor parallelism.";
        };

        enablePrefixCaching = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable prefix caching (recommended for agents).";
        };

        enableChunkedPrefill = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable chunked prefill to reduce memory spikes.";
        };

        trustRemoteCode = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Allow remote code execution from HF models.";
        };

        toolCallParser = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "mistral"
              "llama3_json"
              "hermes"
              "xlam"
              "qwen3_coder"
            ]
          );
          default = null;
          description = "Tool call parser (enables auto-tool-choice).";
        };

        reasoningParser = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "deepseek_r1"
              "qwen3"
            ]
          );
          default = null;
          description = "Reasoning parser for CoT extraction.";
        };

        servedModelName = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Custom model name in API responses.";
        };

        disableLogStats = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Disable statistics logging.";
        };

        warmupOnStart = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Send a warmup request after startup to pre-compile JIT kernels.";
        };

        warmupTimeout = lib.mkOption {
          type = types.ints.positive;
          default = 300;
          description = ''
            Upper bound (s) on the warmup script. Retries every 5s,
            gives up after ceil(timeout/5) attempts (minimum 1).
          '';
        };

        warmupPayload = lib.mkOption {
          type = types.nullOr (types.attrsOf types.anything);
          default = null;
          description = ''
            Override JSON body POSTed to /v1/chat/completions for warmup.
            Null uses a minimal default `{model, messages, max_tokens: 1}`.
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
          description = "Additional vLLM serve arguments.";
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
          HF_HUB_ENABLE_HF_TRANSFER = "1";
          HF_HUB_DOWNLOAD_TIMEOUT = "600";
        }
        // c.environmentVariables;
        volumes = [
          "${cfg.cacheDir}:/root/.cache/huggingface:rw"
        ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
        cmd = [ c.model ] ++ mkServeArgs c;
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
      default = "vllm/vllm-openai:v0.15.1";
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

    systemd.services = lib.mkMerge (
      map (
        name:
        let
          c = cfg.instances.${name};
          containerService = "podman-${serviceName}-${name}";
          modelName = if c.servedModelName != null then c.servedModelName else c.model;
          endpoint = "http://${c.host}:${toString c.port}";
          retries = toString (lib.max 1 ((c.warmupTimeout + 4) / 5));
          defaultPayload = {
            model = modelName;
            messages = [
              {
                role = "user";
                content = "warmup";
              }
            ];
            max_tokens = 1;
          };
          warmupBody = if c.warmupPayload != null then c.warmupPayload else defaultPayload;
          warmupBodyJson = builtins.toJSON warmupBody;
        in
        lib.mkIf c.warmupOnStart {
          "${containerService}".serviceConfig.ExecStartPost = [
            (pkgs.writeShellScript "vllm-warmup-${name}" ''
              set -u
              for i in $(seq 1 ${retries}); do
                if ${pkgs.curl}/bin/curl -sf ${endpoint}/health \
                   && ${pkgs.curl}/bin/curl -sf ${endpoint}/v1/chat/completions \
                        -H "Content-Type: application/json" \
                        -o /dev/null \
                        -d ${lib.escapeShellArg warmupBodyJson}; then
                  exit 0
                fi
                sleep 5
              done
              echo "vllm-warmup-${name}: timed out after ${retries} attempts (${toString c.warmupTimeout}s)" >&2
              exit 1
            '')
          ];
        }
      ) instances
    );

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
