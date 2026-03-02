{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "vllm";
  cfg = config.codgician.services.vllm;
  types = lib.types;

  defaultCacheDir = "/var/lib/vllm-cache";

  # Helper to build vLLM serve command arguments as a list
  mkServeArgsList =
    instanceCfg:
    [
      "--host"
      instanceCfg.host
      "--port"
      (builtins.toString instanceCfg.port)
      "--download-dir"
      cfg.cacheDir
    ]
    ++ lib.optionals (instanceCfg.maxModelLen != null) [
      "--max-model-len"
      (builtins.toString instanceCfg.maxModelLen)
    ]
    ++ lib.optionals (instanceCfg.quantization != null) [
      "--quantization"
      instanceCfg.quantization
    ]
    ++ lib.optionals (instanceCfg.tensorParallelSize != 1) [
      "--tensor-parallel-size"
      (builtins.toString instanceCfg.tensorParallelSize)
    ]
    ++ lib.optionals (instanceCfg.gpuMemoryUtilization != 0.9) [
      "--gpu-memory-utilization"
      (builtins.toString instanceCfg.gpuMemoryUtilization)
    ]
    ++ lib.optionals (instanceCfg.kvCacheDtype != "auto") [
      "--kv-cache-dtype"
      instanceCfg.kvCacheDtype
    ]
    ++ lib.optionals instanceCfg.enablePrefixCaching [
      "--enable-prefix-caching"
    ]
    ++ lib.optionals (instanceCfg.maxNumSeqs != 256) [
      "--max-num-seqs"
      (builtins.toString instanceCfg.maxNumSeqs)
    ]
    ++ lib.optionals instanceCfg.trustRemoteCode [
      "--trust-remote-code"
    ]
    ++ lib.optionals instanceCfg.enableChunkedPrefill [
      "--enable-chunked-prefill"
    ]
    ++ lib.optionals instanceCfg.disableLogStats [
      "--disable-log-stats"
    ]
    ++ lib.optionals (instanceCfg.servedModelName != null) [
      "--served-model-name"
      instanceCfg.servedModelName
    ]
    ++ lib.optionals (instanceCfg.toolCallParser != null) [
      "--enable-auto-tool-choice"
      "--tool-call-parser"
      instanceCfg.toolCallParser
    ]
    ++ lib.optionals (instanceCfg.reasoningParser != null) [
      "--reasoning-parser"
      instanceCfg.reasoningParser
    ]
    ++ instanceCfg.extraArgs;

  # Instance options submodule
  instanceModule =
    { config, name, ... }:
    {
      options = {
        model = lib.mkOption {
          type = types.str;
          description = "HuggingFace model name or path to serve.";
          example = "Qwen/Qwen3.5-35B-A3B-AWQ";
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

        # GPU Memory Management
        gpuMemoryUtilization = lib.mkOption {
          type = types.float;
          default = 0.9;
          description = ''
            Fraction of GPU memory to use for the KV cache (0.0-1.0).
            Lower values leave more memory for other processes.
          '';
          example = 0.7;
        };

        kvCacheDtype = lib.mkOption {
          type = types.enum [
            "auto"
            "fp8"
            "fp8_e5m2"
            "fp8_e4m3"
          ];
          default = "auto";
          description = ''
            Data type for KV cache. Using fp8 can reduce memory by ~50%.
          '';
        };

        # Model Configuration
        maxModelLen = lib.mkOption {
          type = types.nullOr types.int;
          default = null;
          description = ''
            Maximum sequence length. If null, uses model's default.
            Reducing this saves memory.
          '';
          example = 32768;
        };

        maxNumSeqs = lib.mkOption {
          type = types.int;
          default = 256;
          description = "Maximum number of concurrent sequences.";
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
          description = "Quantization method for the model.";
          example = "awq";
        };

        tensorParallelSize = lib.mkOption {
          type = types.int;
          default = 1;
          description = "Number of GPUs for tensor parallelism.";
        };

        # Features
        enablePrefixCaching = lib.mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable automatic prefix caching for repeated prompts.
            Highly recommended for agentic workflows.
          '';
        };

        enableChunkedPrefill = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Enable chunked prefill to reduce memory spikes.";
        };

        trustRemoteCode = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Allow execution of remote code from HuggingFace models.";
        };

        # Tool Calling & Reasoning
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
          description = ''
            Tool call parser for function calling.
            Setting this also enables --enable-auto-tool-choice.
          '';
        };

        reasoningParser = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "deepseek_r1"
              "qwen3"
            ]
          );
          default = null;
          description = "Reasoning parser for chain-of-thought extraction.";
        };

        servedModelName = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Custom name for the model in API responses.";
          example = "my-model";
        };

        # Logging
        disableLogStats = lib.mkOption {
          type = types.bool;
          default = false;
          description = "Disable statistics logging.";
        };

        # Environment & Extra Args
        environmentVariables = lib.mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Environment variables for the vLLM instance.";
          example = {
            VLLM_ATTENTION_BACKEND = "FLASH_ATTN";
            HF_TOKEN = "hf_xxx";
          };
        };

        extraArgs = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional arguments passed to vLLM serve.";
          example = [
            "--enable-lora"
            "--max-loras=4"
          ];
        };

        # Reverse proxy
        reverseProxy = lib.codgician.mkServiceReverseProxyOptions {
          serviceName = "${serviceName}@${name}";
          defaultProxyPass = "http://${config.host}:${builtins.toString config.port}";
          defaultProxyPassText = "http://\${config.host}:\${toString config.port}";
        };
      };
    };

  # Make systemd service config for nixpkgs backend
  mkNixpkgsSystemdConfig =
    instance:
    let
      instanceCfg = cfg.instances.${instance};
      serveArgs = mkServeArgsList instanceCfg;
    in
    {
      "vllm@${instance}" = {
        enable = true;
        description = "vLLM inference server: ${instance}";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
        ]
        ++ lib.optionals cfg.cuda [ "nvidia-gpu-config.service" ];
        wants = lib.optionals cfg.cuda [ "nvidia-gpu-config.service" ];

        environment = {
          HOME = "/var/lib/vllm/${instance}";
          VLLM_CACHE_ROOT = cfg.cacheDir;
          VLLM_NO_USAGE_STATS = "1";
        }
        // instanceCfg.environmentVariables;

        # Use script for proper shell handling of arguments
        script = ''
          exec ${lib.getExe cfg.package} serve ${lib.escapeShellArg instanceCfg.model} \
            ${lib.escapeShellArgs serveArgs}
        '';

        serviceConfig = {
          Type = "simple";

          # Per-instance directories to avoid conflicts
          WorkingDirectory = "/var/lib/vllm/${instance}";
          StateDirectory = "vllm/${instance}";
          RuntimeDirectory = "vllm/${instance}";
          CacheDirectory = "vllm";

          # User/Group - use static user for GPU access
          User = cfg.user;
          Group = cfg.group;

          # GPU Access via supplementary groups (simple approach)
          SupplementaryGroups = lib.optionals cfg.cuda [
            "video"
            "render"
          ];

          # Hardening (relaxed for GPU access)
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [
            cfg.cacheDir
            "/var/lib/vllm"
          ];

          # Resource limits
          LimitNOFILE = 65536;
          LimitMEMLOCK = "infinity";

          # Restart policy
          Restart = "on-failure";
          RestartSec = 10;

          # Timeouts - vLLM can take a while to load models
          TimeoutStartSec = 600;
          TimeoutStopSec = 30;
        };
      };
    };

  # Make OCI container config
  mkContainerConfig =
    instance:
    let
      instanceCfg = cfg.instances.${instance};
      # Reuse the same args builder for container backend (feature parity)
      serveArgs = mkServeArgsList instanceCfg;
      # Build environment for container
      containerEnv = {
        VLLM_NO_USAGE_STATS = "1";
      }
      // instanceCfg.environmentVariables;
    in
    {
      "${serviceName}-${instance}" = {
        autoStart = true;
        image = "vllm/vllm-openai:${cfg.imageTag}";

        environment = containerEnv;

        volumes = [
          "${cfg.cacheDir}:/root/.cache/huggingface:rw"
        ];

        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals cfg.cuda [
          "--device=nvidia.com/gpu=all"
        ];

        # Use the unified serveArgs for feature parity with nixpkgs backend
        cmd = [
          "--model"
          instanceCfg.model
        ]
        ++ serveArgs;
      };
    };

  # Make reverse proxy config
  mkReverseProxyConfig =
    instance:
    lib.codgician.mkServiceReverseProxyConfig {
      serviceName = "${serviceName}@${instance}";
      cfg = cfg.instances.${instance};
    };

  instanceNames = builtins.attrNames cfg.instances;
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
      description = ''
        Backend for running vLLM.
        - nixpkgs: Native package from nixpkgs (requires CUDA build)
        - container: Official Docker image (recommended for reliability)
      '';
    };

    package = lib.mkPackageOption pkgs "vllm" { };

    imageTag = lib.mkOption {
      type = types.str;
      default = "v0.15.1";
      description = "Docker image tag for container backend.";
      example = "latest";
    };

    cuda = lib.mkOption {
      type = types.bool;
      # Fixed: Use boolean || instead of Nix attribute `or`
      default =
        (config.hardware.nvidia-container-toolkit.enable or false)
        || (config.nixpkgs.config.cudaSupport or false);
      defaultText = "(config.hardware.nvidia-container-toolkit.enable or false) || (config.nixpkgs.config.cudaSupport or false)";
      description = "Enable CUDA/GPU support for vLLM.";
    };

    user = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "User under which vLLM runs (nixpkgs backend only).";
    };

    group = lib.mkOption {
      type = types.str;
      default = serviceName;
      description = "Group under which vLLM runs (nixpkgs backend only).";
    };

    cacheDir = lib.mkOption {
      type = types.path;
      default = defaultCacheDir;
      description = "Directory for vLLM to cache model weights.";
    };

    instances = lib.mkOption {
      type = types.attrsOf (types.submodule instanceModule);
      default = { };
      description = "vLLM server instances to run.";
      example = lib.literalExpression ''
        {
          qwen = {
            model = "Qwen/Qwen3.5-35B-A3B-AWQ";
            port = 8000;
            quantization = "awq";
            maxModelLen = 131072;
            enablePrefixCaching = true;
            gpuMemoryUtilization = 0.85;
          };
        }
      '';
    };
  };

  config = lib.mkMerge [
    # Common config
    (lib.mkIf (cfg.enable && cfg.instances != { }) {
      # Create user/group for nixpkgs backend
      users.users.${cfg.user} = lib.mkIf (cfg.backend == "nixpkgs") {
        isSystemUser = true;
        group = cfg.group;
        home = "/var/lib/vllm";
        description = "vLLM service user";
      };

      users.groups.${cfg.group} = lib.mkIf (cfg.backend == "nixpkgs") { };

      # Always ensure cache directory exists with proper ownership
      systemd.tmpfiles.rules = [
        # Always create/ensure cache directory
        "d ${cfg.cacheDir} 0755 ${if cfg.backend == "nixpkgs" then cfg.user else "root"} ${
          if cfg.backend == "nixpkgs" then cfg.group else "root"
        } -"
      ]
      ++ lib.optionals (cfg.backend == "nixpkgs") [
        # Create base vllm state directory
        "d /var/lib/vllm 0755 ${cfg.user} ${cfg.group} -"
      ];

      # Persist cache directory (only when using default location)
      codgician.system.impermanence.extraItems = lib.mkIf (cfg.cacheDir == defaultCacheDir) [
        {
          type = "directory";
          path = cfg.cacheDir;
        }
      ];
    })

    # Nixpkgs backend
    (lib.mkIf (cfg.enable && cfg.backend == "nixpkgs" && cfg.instances != { }) {
      systemd.services = lib.mkMerge (builtins.map mkNixpkgsSystemdConfig instanceNames);
    })

    # Container backend
    (lib.mkIf (cfg.enable && cfg.backend == "container" && cfg.instances != { }) {
      virtualisation.oci-containers.containers = lib.mkMerge (
        builtins.map mkContainerConfig instanceNames
      );
    })

    # Reverse proxy for all backends
    (lib.mkIf (cfg.enable && cfg.instances != { }) {
      codgician.services.nginx = lib.mkMerge (builtins.map mkReverseProxyConfig instanceNames);
    })
  ];
}
