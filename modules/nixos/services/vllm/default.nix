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

  # Build vLLM serve command arguments as a list
  mkServeArgs =
    c:
    lib.optionals (c.task != null) [
      "--task"
      c.task
    ]
    ++ [
      "--host"
      c.host
      "--port"
      (toString c.port)
      "--download-dir"
      cfg.cacheDir
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
    ++ lib.optionals (c.kvCacheDtype != "auto") [
      "--kv-cache-dtype"
      c.kvCacheDtype
    ]
    ++ lib.optionals (c.maxNumSeqs != 256) [
      "--max-num-seqs"
      (toString c.maxNumSeqs)
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

  # Instance submodule
  instanceModule =
    { config, name, ... }:
    {
      options = {
        model = lib.mkOption {
          type = types.str;
          description = "HuggingFace model name or path to serve.";
          example = "Qwen/Qwen3.5-35B-A3B-AWQ";
        };

        task = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "generate"
              "embed"
              "classify"
              "score"
            ]
          );
          default = null;
          description = "Task type. Use 'embed' for embedding models, 'classify' for classification, 'score' for scoring. Null means auto-detect (usually 'generate').";
          example = "embed";
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

        quantization = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "awq"
              "gptq"
              "fp8"
              "gguf"
              "bitsandbytes"
              "marlin"
            ]
          );
          default = null;
          description = "Quantization method.";
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

  # Generate systemd service for an instance
  mkSystemdService = name: {
    "vllm@${name}" =
      let
        c = cfg.instances.${name};
      in
      {
        description = "vLLM: ${name}";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optionals cfg.cuda [ "nvidia-gpu-config.service" ];
        wants = lib.optionals cfg.cuda [ "nvidia-gpu-config.service" ];

        environment = {
          HOME = "/var/lib/vllm/${name}";
          VLLM_CACHE_ROOT = cfg.cacheDir;
          VLLM_NO_USAGE_STATS = "1";
        }
        // c.environmentVariables;

        script = ''
          exec ${lib.getExe cfg.package} serve ${lib.escapeShellArg c.model} \
            ${lib.escapeShellArgs (mkServeArgs c)}
        '';

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = "/var/lib/vllm/${name}";
          StateDirectory = "vllm/${name}";
          RuntimeDirectory = "vllm/${name}";
          CacheDirectory = "vllm";
          SupplementaryGroups = lib.optionals cfg.cuda [
            "video"
            "render"
          ];
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            cfg.cacheDir
            "/var/lib/vllm"
          ];
          LimitNOFILE = 65536;
          LimitMEMLOCK = "infinity";
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStartSec = 600;
          TimeoutStopSec = 30;
        };
      };
  };

  # Generate OCI container for an instance
  mkContainer = name: {
    "${serviceName}-${name}" =
      let
        c = cfg.instances.${name};
      in
      {
        autoStart = true;
        image = "vllm/vllm-openai:${cfg.imageTag}";
        environment = {
          VLLM_NO_USAGE_STATS = "1";
        }
        // c.environmentVariables;
        volumes = [ "${cfg.cacheDir}:/root/.cache/huggingface:rw" ];
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
        cmd = [
          "--model"
          c.model
        ]
        ++ mkServeArgs c;
      };
  };

  instances = builtins.attrNames cfg.instances;
  hasInstances = cfg.enable && cfg.instances != { };
in
{
  options.codgician.services.vllm = {
    enable = lib.mkEnableOption "vLLM inference server";

    backend = lib.mkOption {
      type = types.enum [
        "nixpkgs"
        "container"
      ];
      default = "nixpkgs";
      description = "Backend: nixpkgs (native) or container (Docker).";
    };

    package = lib.mkPackageOption pkgs "vllm" { };

    imageTag = lib.mkOption {
      type = types.str;
      default = "v0.15.1";
      description = "Docker image tag for container backend.";
    };

    cuda = lib.mkOption {
      type = types.bool;
      default =
        (config.hardware.nvidia-container-toolkit.enable or false)
        || (config.nixpkgs.config.cudaSupport or false);
      description = "Enable CUDA/GPU support.";
    };

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "User for vLLM (nixpkgs backend).";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group for vLLM (nixpkgs backend).";
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = defaultCacheDir;
      description = "Model cache directory.";
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
      description = "vLLM server instances.";
    };
  };

  config = lib.mkIf hasInstances (
    lib.mkMerge [
      # User/group and directories
      {
        users.users.${cfg.user} = lib.mkIf (cfg.backend == "nixpkgs") {
          isSystemUser = true;
          group = cfg.group;
          home = "/var/lib/vllm";
          description = "vLLM service user";
        };
        users.groups.${cfg.group} = lib.mkIf (cfg.backend == "nixpkgs") { };

        systemd.tmpfiles.rules =
          let
            owner = if cfg.backend == "nixpkgs" then cfg.user else "root";
            grp = if cfg.backend == "nixpkgs" then cfg.group else "root";
          in
          [ "d ${cfg.cacheDir} 0755 ${owner} ${grp} -" ]
          ++ lib.optionals (cfg.backend == "nixpkgs") [ "d /var/lib/vllm 0755 ${cfg.user} ${cfg.group} -" ];

        codgician.system.impermanence.extraItems = lib.mkIf (cfg.cacheDir == defaultCacheDir) [
          {
            type = "directory";
            path = cfg.cacheDir;
          }
        ];
      }

      # Backend-specific config
      (lib.mkIf (cfg.backend == "nixpkgs") {
        systemd.services = lib.mkMerge (map mkSystemdService instances);
      })

      (lib.mkIf (cfg.backend == "container") {
        virtualisation.oci-containers.containers = lib.mkMerge (map mkContainer instances);
      })

      # Reverse proxy
      {
        codgician.services.nginx = lib.mkMerge (
          map (
            i:
            lib.codgician.mkServiceReverseProxyConfig {
              serviceName = "${serviceName}@${i}";
              cfg = cfg.instances.${i};
            }
          ) instances
        );
      }
    ]
  );
}
