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
  defaultInstanceDataDir = name: "/var/lib/vllm/${name}";

  # Derive warmup endpoint from modality when not explicitly set.
  # Omni instances default to "health" (just wait for /health) since a
  # synthesis probe typically needs per-model voice/ref payloads that
  # generic defaults can't cover. Non-omni defaults to "chat".
  effectiveWarmupEndpoint =
    c:
    if c.warmupEndpoint != null then
      c.warmupEndpoint
    else if c.omni.enable then
      "health"
    else
      "chat";

  # Default JSON body per warmup endpoint (null when endpoint is "health").
  defaultWarmupPayload =
    endpoint: modelName:
    if endpoint == "health" then
      null
    else if endpoint == "chat" then
      {
        model = modelName;
        messages = [
          {
            role = "user";
            content = "warmup";
          }
        ];
        max_tokens = 1;
      }
    else if endpoint == "audio" then
      {
        model = modelName;
        input = "warmup";
        voice = "default";
      }
    else if endpoint == "images" then
      {
        model = modelName;
        prompt = "warmup";
        n = 1;
        size = "256x256";
      }
    else
      throw "vllm: unknown warmupEndpoint '${endpoint}'";

  warmupPath =
    endpoint:
    {
      health = "/health";
      chat = "/v1/chat/completions";
      audio = "/v1/audio/speech";
      images = "/v1/images/generations";
    }
    .${endpoint};

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
    ++ lib.optional c.omni.enable "--omni"
    ++ lib.optionals (c.omni.enable && c.omni.taskType != null) [
      "--task-type"
      c.omni.taskType
    ]
    ++ lib.optionals (c.omni.enable && c.omni.stageConfigsPath != null) [
      "--stage-configs-path"
      "/etc/vllm-omni/stage-configs.yaml"
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
    ++ lib.optionals (!c.omni.enable && c.toolCallParser != null) [
      "--enable-auto-tool-choice"
      "--tool-call-parser"
      c.toolCallParser
    ]
    ++ lib.optionals (!c.omni.enable && c.reasoningParser != null) [
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

        omni = lib.mkOption {
          default = { };
          description = "vllm-omni multimodal mode configuration.";
          type = types.submodule {
            options = {
              enable = lib.mkEnableOption ''
                vllm-omni mode (multimodal: TTS/ASR/image-gen/omni-chat).
                Appends `--omni` and requires a `vllm/vllm-omni:<tag>` image.
              '';

              taskType = lib.mkOption {
                type = types.nullOr (
                  types.enum [
                    "Base"
                    "CustomVoice"
                    "VoiceDesign"
                  ]
                );
                default = null;
                description = "Maps to `--task-type`. Required for TTS models.";
              };

              stageConfigsPath = lib.mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Custom stage-pipeline YAML. Usually unset (image ships defaults).";
              };

              voicesBootstrap = lib.mkOption {
                type = types.attrsOf (
                  types.submodule {
                    options = {
                      audio = lib.mkOption {
                        type = types.path;
                        description = "Absolute path to the reference audio file (wav/mp3/flac/etc).";
                      };
                      refTextFile = lib.mkOption {
                        type = types.nullOr types.path;
                        default = null;
                        description = ''
                          Absolute path to a text file containing the transcript
                          of the reference clip. Read at container-start time by
                          the warmup script (not inlined into Nix). Strongly
                          recommended for fishaudio/s2-pro — omitting it
                          degrades cloning quality (vllm-omni #2552).
                        '';
                      };
                      consent = lib.mkOption {
                        type = types.str;
                        default = "granted";
                        description = "Consent metadata required by POST /v1/audio/voices.";
                      };
                    };
                  }
                );
                default = { };
                example = lib.literalExpression ''
                  {
                    codgi = {
                      audio = "/xpool/llm/vllm/fishaudio/voices/codgi.wav";
                      refTextFile = "/xpool/llm/vllm/fishaudio/voices/codgi.txt";
                    };
                  }
                '';
                description = ''
                  Voices to auto-register via `POST /v1/audio/voices` after
                  warmup succeeds. Workaround for vllm-omni's ephemeral
                  in-memory registry (upstream #2115).

                  HTTP 2xx and 409 count as success; anything else (4xx/5xx,
                  transport failure, missing file) fails the unit.
                '';
              };
            };
          };
        };

        dataDir = lib.mkOption {
          type = types.path;
          default = defaultInstanceDataDir name;
          defaultText = lib.literalExpression ''"/var/lib/vllm/<name>"'';
          description = ''
            Persistent state directory. Materialized (tmpfiles, `/data`
            mount, impermanence) only when `omni.enable = true`.
          '';
        };

        image = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "vllm/vllm-omni:v0.19.0";
          description = ''
            Full image ref overriding `cfg.image` for this instance.
            Must point at a `vllm/vllm-omni:<tag>` when `omni.enable = true`.
          '';
        };

        entrypoint = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "vllm"
            "serve"
          ];
          description = ''
            Tokens to prepend to the container `cmd` (the served-model and
            CLI args). Needed for images with no useful ENTRYPOINT — notably
            `vllm/vllm-omni`, which ships an empty entrypoint while
            `vllm/vllm-openai` ships `["vllm", "serve"]`. Leave empty if
            the image's own ENTRYPOINT already invokes `vllm serve`.
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
          description = ''
            Tool call parser (enables auto-tool-choice).
            Ignored when `omni.enable = true`.
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
          description = ''
            Reasoning parser for CoT extraction.
            Ignored when `omni.enable = true`.
          '';
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

        warmupEndpoint = lib.mkOption {
          type = types.nullOr (
            types.enum [
              "health"
              "chat"
              "audio"
              "images"
            ]
          );
          default = null;
          description = ''
            Warmup probe endpoint. "health" only polls /health (used to
            gate voice bootstrap without triggering synthesis); "chat",
            "audio", "images" additionally POST to /v1/chat/completions,
            /v1/audio/speech, /v1/images/generations respectively.
            Null auto-derives: "health" for omni instances, "chat" for
            plain LLM instances.
          '';
        };

        warmupPayload = lib.mkOption {
          type = types.nullOr (types.attrsOf types.anything);
          default = null;
          description = ''
            Override JSON body sent to the warmup endpoint. Null uses a
            per-endpoint default keyed on the served model name.
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
          # Improve HuggingFace download reliability
          HF_HUB_ENABLE_HF_TRANSFER = "1";
          HF_HUB_DOWNLOAD_TIMEOUT = "600";
        }
        // c.environmentVariables;
        volumes = [
          "${cfg.cacheDir}:/root/.cache/huggingface:rw"
        ]
        ++ lib.optional c.omni.enable "${c.dataDir}:/data:rw"
        ++ lib.optional (
          c.omni.enable && c.omni.stageConfigsPath != null
        ) "${toString c.omni.stageConfigsPath}:/etc/vllm-omni/stage-configs.yaml:ro";
        extraOptions = [
          "--pull=newer"
          "--net=host"
          "--shm-size=8g"
          "--ulimit=memlock=-1"
        ]
        ++ lib.optionals cfg.cuda [ "--device=nvidia.com/gpu=all" ];
        cmd = c.entrypoint ++ [ c.model ] ++ mkServeArgs c;
      };
  };

  instances = builtins.attrNames cfg.instances;
  hasInstances = cfg.enable && cfg.instances != { };

  omniInstances = lib.filter (n: cfg.instances.${n}.omni.enable) instances;
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
        Override per-instance for omni (which needs a `vllm/vllm-omni:<tag>`).
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
    # Eval-time sanity checks for common misconfigurations.
    assertions =
      let
        perInstance = lib.concatMap (
          n:
          let
            c = cfg.instances.${n};
            effectiveImage = if c.image != null then c.image else cfg.image;
            hasOmniRepo = lib.hasInfix "vllm-omni" effectiveImage;
          in
          [
            {
              assertion = !c.omni.enable || hasOmniRepo;
              message =
                "codgician.services.vllm.instances.${n}: `omni.enable = true` but image "
                + "`${effectiveImage}` does not look like a `vllm/vllm-omni` image. "
                + "Set `instances.${n}.image` (or `codgician.services.vllm.image`) to a "
                + "`vllm/vllm-omni:<tag>` reference.";
            }
            {
              assertion = c.omni.voicesBootstrap == { } || (c.omni.enable && c.warmupOnStart);
              message =
                "codgician.services.vllm.instances.${n}: `omni.voicesBootstrap` is non-empty "
                + "but requires both `omni.enable = true` and `warmupOnStart = true` "
                + "(voice registration is chained to the warmup script).";
            }
            {
              assertion =
                c.omni.enable
                || (c.omni.taskType == null && c.omni.stageConfigsPath == null && c.omni.voicesBootstrap == { });
              message =
                "codgician.services.vllm.instances.${n}: `omni.{taskType,stageConfigsPath,voicesBootstrap}` "
                + "are only effective with `omni.enable = true`. Set `omni.enable = true` or unset these.";
            }
            {
              assertion = !c.omni.enable || (c.toolCallParser == null && c.reasoningParser == null);
              message =
                "codgician.services.vllm.instances.${n}: `toolCallParser`/`reasoningParser` are "
                + "ignored when `omni.enable = true`. Unset them on omni instances.";
            }
          ]
        ) instances;

        # `--net=host` means (host, port) pairs must be unique.
        endpointPairs = map (n: {
          inherit n;
          key = "${cfg.instances.${n}.host}:${toString cfg.instances.${n}.port}";
        }) instances;
        portAssertions =
          let
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
      in
      perInstance ++ portAssertions;

    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root -"
    ]
    ++ map (n: "d ${cfg.instances.${n}.dataDir} 0755 root root -") omniInstances;

    codgician.system.impermanence.extraItems =
      (lib.optional (cfg.cacheDir == defaultCacheDir) {
        type = "directory";
        path = cfg.cacheDir;
      })
      ++ map (n: {
        type = "directory";
        path = cfg.instances.${n}.dataDir;
      }) (lib.filter (n: cfg.instances.${n}.dataDir == defaultInstanceDataDir n) omniInstances);

    virtualisation.oci-containers.containers = lib.mkMerge (map mkContainer instances);

    # Warmup + voice bootstrap. Fails the unit on timeout or voice error.
    systemd.services = lib.mkMerge (
      map (
        name:
        let
          c = cfg.instances.${name};
          containerService = "podman-${serviceName}-${name}";
          modelName = if c.servedModelName != null then c.servedModelName else c.model;
          endpoint = "http://${c.host}:${toString c.port}";
          # Ceil(timeout/5), minimum 1.
          retries = toString (lib.max 1 ((c.warmupTimeout + 4) / 5));
          warmupEp = effectiveWarmupEndpoint c;
          warmupBody =
            if c.warmupPayload != null then c.warmupPayload else defaultWarmupPayload warmupEp modelName;
          warmupBodyJson = builtins.toJSON warmupBody;
          warmupUrl = "${endpoint}${warmupPath warmupEp}";

          # Per-voice registration block. POST returns 2xx, then we GET
          # /v1/audio/voices to confirm the name actually appears in the
          # listing (the server may return 200 but silently drop a voice
          # that fails internal validation, e.g. reference-clip length
          # limits in Qwen3-TTS-Base). A 2xx/409 that doesn't produce a
          # visible voice is treated as a failure.
          #
          # `--form-string` keeps `@`/`<` in text fields from being parsed by
          # curl; `-F ref_text=<PATH` reads the transcript file contents
          # verbatim at runtime (UTF-8-safe, no shell substitution).
          voiceRegCmds = lib.mapAttrsToList (vname: v: ''
            echo "voice[${vname}]: registering..."
            if [ ! -r ${lib.escapeShellArg (toString v.audio)} ]; then
              echo "voice[${vname}]: ERROR audio file missing: ${toString v.audio}" >&2
              voice_failed=1
            ${
              lib.optionalString (v.refTextFile != null) ''
                elif [ ! -r ${lib.escapeShellArg (toString v.refTextFile)} ]; then
                  echo "voice[${vname}]: ERROR refText file missing: ${toString v.refTextFile}" >&2
                  voice_failed=1
              ''
            }else
              vcode=$(${pkgs.curl}/bin/curl -sS -o /tmp/voice-${vname}.body \
                -w '%{http_code}' \
                -X POST ${endpoint}/v1/audio/voices \
                --form-string ${lib.escapeShellArg "name=${vname}"} \
                -F ${lib.escapeShellArg "audio_sample=@${toString v.audio}"} \
                ${
                  lib.optionalString (
                    v.refTextFile != null
                  ) "-F ${lib.escapeShellArg "ref_text=<${toString v.refTextFile}"}"
                } \
                --form-string ${lib.escapeShellArg "consent=${v.consent}"} \
              ) || { echo "voice[${vname}]: ERROR curl transport failure" >&2; voice_failed=1; vcode=000; }
              case "$vcode" in
                2*|409)
                  # Verify the server actually registered it (catches silent drops).
                  if ${pkgs.curl}/bin/curl -sS ${endpoint}/v1/audio/voices \
                      | ${pkgs.gnugrep}/bin/grep -q ${lib.escapeShellArg ''"${vname}"''}; then
                    echo "voice[${vname}]: OK (HTTP $vcode, verified)"
                  else
                    echo "voice[${vname}]: ERROR HTTP $vcode but voice not in /v1/audio/voices listing (silently dropped). Body:" >&2
                    cat /tmp/voice-${vname}.body >&2 || true
                    voice_failed=1
                  fi
                  ;;
                *)
                  echo "voice[${vname}]: ERROR HTTP $vcode, body:" >&2
                  cat /tmp/voice-${vname}.body >&2 || true
                  voice_failed=1
                  ;;
              esac
              rm -f /tmp/voice-${vname}.body
            fi
          '') (if c.omni.enable then c.omni.voicesBootstrap else { });
          voiceRegBlock = lib.concatStringsSep "\n" voiceRegCmds;
        in
        lib.mkIf c.warmupOnStart {
          "${containerService}".serviceConfig.ExecStartPost = [
            (pkgs.writeShellScript "vllm-warmup-${name}" ''
              set -u
              voice_failed=0
              for i in $(seq 1 ${retries}); do
                if ${pkgs.curl}/bin/curl -sf ${endpoint}/health${
                  lib.optionalString (warmupEp != "health") ''
                    \
                                      && ${pkgs.curl}/bin/curl -sf ${warmupUrl} \
                                           -H "Content-Type: application/json" \
                                           -o /dev/null \
                                           -d ${lib.escapeShellArg warmupBodyJson}''
                }; then
                  ${
                    if voiceRegCmds == [ ] then
                      ""
                    else
                      ''
                        # Warmup succeeded; register declarative voice library.
                        ${voiceRegBlock}
                      ''
                  }
                  if [ "$voice_failed" -ne 0 ]; then
                    echo "vllm-warmup-${name}: one or more voice registrations failed" >&2
                    exit 1
                  fi
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
