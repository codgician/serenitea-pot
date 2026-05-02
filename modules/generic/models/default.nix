# Model registry module with typed provider specifications
{
  config,
  lib,
  pkgs,
  outputs,
  ...
}:
let
  cfg = config.codgician.models;
  inherit (lib) types mkOption;

  # Terraform config for Azure validation
  terraformConf =
    builtins.fromJSON
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.value;
  azureSubdomain = terraformConf.resource.azurerm_ai_services.akasha.custom_subdomain_name;
  deployedModelNames = lib.mapAttrsToList (_: v: v.name) (
    terraformConf.resource.azurerm_cognitive_deployment or { }
  );

  # ===========================================================================
  # Common option definitions (shared across provider types)
  # ===========================================================================
  variantsType = types.attrsOf (types.attrsOf types.anything);

  commonOptions = {
    aliases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Alternative names for this model";
    };
    mode = mkOption {
      type = types.str;
      default = "chat";
      description = "Model mode (chat, image_generation, embedding, etc.)";
    };
    variants = mkOption {
      type = variantsType;
      default = { };
      description = "Model variants (e.g., reasoning effort levels)";
    };
    path = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Provider-local model path override; defaults to the model name.";
    };
  };

  # ===========================================================================
  # Provider-specific model types (extending common options)
  # ===========================================================================

  # Basic type for simple providers
  basicModelType = types.submodule {
    options = commonOptions;
  };

  # Azure: adds provider backend selection and baseModel override
  azureModelType = types.submodule {
    options = commonOptions // {
      provider = mkOption {
        type = types.enum [
          "azure"
          "azure_ai"
        ];
        default = "azure";
        description = "Azure provider type";
      };
      baseModel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override base_model (e.g., for versioned deployments)";
      };
    };
  };

  # Provider submodule: pairs a transformer with its models
  mkProviderType =
    modelType:
    types.submodule {
      options = {
        transformer = mkOption {
          type = types.raw;
          description = "Function (name: spec: { ... }) that transforms a model spec into a registry entry";
        };
        models = mkOption {
          type = types.attrsOf modelType;
          default = { };
          description = "Model definitions for this provider";
        };
      };
    };

  # ===========================================================================
  # Provider Transformers (typed spec → registry entry)
  # ===========================================================================

  mkModel =
    {
      modelPrefix,
      apiKeyEnv ? null,
      tags,
      extraParams ? { },
      extraModelInfo ? { },
    }:
    name: spec: {
      inherit (spec) aliases mode variants;
      litellmModelInfo = {
        inherit (spec) mode;
      }
      // extraModelInfo;
      litellmParams = {
        model = "${modelPrefix}/${if spec.path != null then spec.path else name}";
      }
      // lib.optionalAttrs (apiKeyEnv != null) { api_key = "os.environ/${apiKeyEnv}"; }
      // extraParams;
      inherit tags;
    };

  # ===========================================================================
  # Variant Definitions (shared across providers)
  # ===========================================================================

  # Claude Sonnet 4.6 effort-based variants
  # See: https://platform.claude.com/docs/en/build-with-claude/effort
  claudeSonnet46 = lib.genAttrs [ "high" "medium" "low" ] (effort: {
    thinking = {
      type = "adaptive";
      display = "summarized";
    };
    output_config = { inherit effort; };
  });

  # Claude Opus 4.6 extends Sonnet 4.6 with max effort
  claudeOpus46 = lib.genAttrs [ "max" "high" "medium" "low" ] (effort: {
    thinking = {
      type = "adaptive";
      display = "summarized";
    };
    output_config = { inherit effort; };
  });

  # Claude Opus 4.7 extends Opus 4.7 with xhigh effort
  claudeOpus47 = lib.genAttrs [ "max" "xhigh" "high" "medium" "low" ] (effort: {
    thinking = {
      type = "adaptive";
      display = "summarized";
    };
    output_config = { inherit effort; };
  });

  # Deepseek reasoning effort variants
  deepseek = {
    none.thinking.type = "disabled";
    high = {
      thinking.type = "enabled";
      reasoningEffort = "high";
    };
    max = {
      thinking.type = "enabled";
      reasoningEffort = "max";
    };
  };

  # GPT-5.2+ reasoning effort variants
  gpt52 = {
    xhigh.reasoningEffort = "xhigh";
    high.reasoningEffort = "high";
    medium.reasoningEffort = "medium";
    low.reasoningEffort = "low";
    none.reasoningEffort = "none";
  };

  # Gemini Pro reasoning variants
  geminiPro = {
    high.reasoningEffort = "high";
    low.reasoningEffort = "low";
  };

  # ===========================================================================
  # Build Registry from typed config
  # ===========================================================================

  registry = lib.mapAttrs (
    provider: providerCfg: lib.mapAttrs providerCfg.transformer providerCfg.models
  ) cfg.providers;

  # Azure Terraform validation (validate directly from input config)
  missingAzureModels = lib.filter (name: !(builtins.elem name deployedModelNames)) (
    lib.attrNames cfg.providers.azure.models
  );

  # Flatten registry to list with provider and model fields
  flattenRegistry =
    reg:
    lib.concatLists (
      lib.mapAttrsToList (
        provider: models: lib.mapAttrsToList (model: attrs: attrs // { inherit provider model; }) models
      ) reg
    );

  # Precompute flattened models once for all derived outputs
  flatModels = flattenRegistry registry;

in
{
  options.codgician.models = {
    # Provider specifications (typed inputs)
    providers = {
      anthropic = mkOption {
        type = mkProviderType basicModelType;
        description = "Anthropic Claude models";
      };
      azure = mkOption {
        type = mkProviderType azureModelType;
        description = "Azure AI models";
      };
      chatgpt = mkOption {
        type = mkProviderType basicModelType;
        description = "ChatGPT models";
      };
      deepseek = mkOption {
        type = mkProviderType basicModelType;
        description = "DeepSeek models";
      };
      google = mkOption {
        type = mkProviderType basicModelType;
        description = "Google Gemini models";
      };
      github = mkOption {
        type = mkProviderType basicModelType;
        description = "GitHub Copilot models";
      };
      nvidia = mkOption {
        type = mkProviderType basicModelType;
        description = "NVIDIA NIM models";
      };
    };

    # Computed outputs (read-only)
    all = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Flat list of all models with provider/model fields";
    };
    textGenerationModels = mkOption {
      type = types.listOf types.attrs;
      readOnly = true;
      description = "Models for text generation (mode = chat or responses)";
    };
    byProvider = mkOption {
      type = types.attrsOf (types.attrsOf types.attrs);
      readOnly = true;
      description = "Models organized by provider: provider → model → attrs";
    };
  };

  config = {
    assertions = [
      {
        assertion = missingAzureModels == [ ];
        message = "Azure models not in Terraform: ${builtins.concatStringsSep ", " missingAzureModels}";
      }
    ];

    codgician.models = {
      # =========================================================================
      # Provider definitions (transformer + models)
      # =========================================================================
      providers = {
        # Anthropic Claude models
        anthropic = {
          transformer =
            name: spec:
            let
              isHaiku = lib.hasInfix "haiku" name;
            in
            mkModel {
              modelPrefix = "anthropic";
              apiKeyEnv = "ANTHROPIC_API_KEY";
              tags = [ "anthropic" ];
              extraParams = {
                use_in_pass_through = true;
                extra_headers = {
                  "anthropic-beta" =
                    "oauth-2025-04-20,interleaved-thinking-2025-05-14,claude-code-20250219,context-1m-2025-08-07,fine-grained-tool-streaming-2025-05-14";
                };
              }
              // lib.optionalAttrs (!isHaiku) { prompt_id = "claude-code"; };
            } name spec;
          models = {
            "claude-opus-4-7" = {
              aliases = [ "claude-opus-4.7" ];
              variants = claudeOpus47;
            };
            # Opus 4.6 supports effort-based control (including max effort)
            "claude-opus-4-6" = {
              aliases = [ "claude-opus-4.6" ];
              variants = claudeOpus46;
            };
            # Haiku doesn't support extended thinking
            "claude-haiku-4-5".aliases = [ "claude-haiku-4.5" ];
            # Sonnet 4.6 supports effort-based control (no max effort)
            "claude-sonnet-4-6" = {
              aliases = [ "claude-sonnet-4.6" ];
              variants = claudeSonnet46;
            };
          };
        };

        # Azure models
        azure = {
          transformer = name: spec: {
            inherit (spec) aliases mode variants;
            litellmModelInfo = {
              inherit (spec) mode;
            }
            // lib.optionalAttrs (spec.baseModel != null) {
              base_model = spec.baseModel;
            };
            litellmParams = {
              model = "${spec.provider}/${if spec.path != null then spec.path else name}";
              api_base = "https://${azureSubdomain}.services.ai.azure.com";
              api_key = "os.environ/AZURE_AKASHA_API_KEY";
            };
            tags = [ "azure" ];
          };
          models = {
            # Azure AI provider - chat models
            "deepseek-v4-flash".provider = "azure_ai";
            "grok-4-20-non-reasoning".provider = "azure_ai";
            "grok-4-20-reasoning".provider = "azure_ai";
            "kimi-k2.6".provider = "azure_ai";

            # Azure AI provider - image generation
            "flux-2-pro" = {
              provider = "azure_ai";
              mode = "image_generation";
              baseModel = "azure_ai/FLUX.2-pro";
            };

            # Azure provider - OpenAI models
            "gpt-4o-transcribe-diarize".mode = "audio_transcription";
            "gpt-5.4-nano" = { };
            "gpt-5.4-pro" = {
              variants = gpt52;
            };
            "gpt-image-2".mode = "image_generation";
            "gpt-audio-1.5".baseModel = "azure/gpt-audio-1.5-2026-02-23";
            "gpt-realtime-1.5" = {
              mode = "realtime";
              baseModel = "azure/gpt-realtime-1.5-2026-02-23";
            };
          };
        };

        # ChatGPT models
        chatgpt = {
          transformer = mkModel {
            modelPrefix = "chatgpt";
            tags = [ "chatgpt" ];
          };
          models = {
            "gpt-5.5" = {
              variants = gpt52;
              mode = "responses";
            };
            "gpt-5.4" = {
              variants = gpt52;
              mode = "responses";
            };
            "gpt-5.3-codex" = {
              variants = gpt52;
              mode = "responses";
            };
          };
        };

        # DeepSeek models
        deepseek = {
          transformer = mkModel {
            modelPrefix = "deepseek";
            apiKeyEnv = "DEEPSEEK_API_KEY";
            tags = [ "deepseek" ];
          };
          models = {
            "deepseek-v4-flash".variants = deepseek;
            "deepseek-v4-pro".variants = deepseek;
          };
        };

        # Google Gemini models (image generation)
        google = {
          transformer =
            name: spec:
            mkModel {
              modelPrefix = "gemini";
              apiKeyEnv = "GEMINI_API_KEY";
              tags = [ "google" ];
            } name (spec // { mode = "image_generation"; });
          models = {
            "gemini-3-pro-image-preview" = { };
            "gemini-3.1-flash-image-preview" = { };
            "gemini-2.5-flash-image" = { };
          };
        };

        # GitHub Copilot models
        github = {
          transformer = mkModel {
            modelPrefix = "github_copilot";
            tags = [ "github" ];
            extraParams.extra_headers = {
              copilot-integration-id = "vscode-chat";
              editor-version = "vscode/${pkgs.vscode.version}";
              editor-plugin-version = "copilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
              openai-intent = "conversation-agent";
              user-agent = "GithubCopilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
              x-interaction-type = "conversation-agent";
            };
          };
          models = {
            # Embedding models
            "text-embedding-3-small".mode = "embedding";
            "text-embedding-3-small-inference".mode = "embedding";
            "text-embedding-ada-002".mode = "embedding";

            # Anthropic models
            "claude-opus-4-7-github" = {
              path = "claude-opus-4-7-1m-internal";
              variants = claudeOpus47;
            };

            "claude-opus-4-6-github" = {
              path = "claude-opus-4-6-1m";
              variants = claudeOpus46;
            };

            # Gemini models
            "gemini-3-flash-preview" = { };
            "gemini-3.1-pro-preview".variants = geminiPro;

            # GPT-5.x chat models
            "gpt-5.2".variants = gpt52;

            # GPT-5.x models (responses mode)
            "gpt-5.2-codex" = {
              mode = "responses";
              variants = gpt52;
            };
            "gpt-5.3-codex" = {
              mode = "responses";
              variants = gpt52;
            };
            "gpt-5.4" = {
              mode = "responses";
              variants = gpt52;
            };
            "gpt-5.4-mini" = {
              mode = "responses";
            };
            # "gpt-5.5" = {
            #   mode = "responses";
            #   variants = gpt52;
            # };
          };
        };

        # NVIDIA NIM models
        nvidia = {
          transformer = mkModel {
            modelPrefix = "nvidia_nim";
            apiKeyEnv = "NVIDIA_NIM_API_KEY";
            tags = [ "nvidia" ];
          };
          models = {
            "glm5.1".path = "z-ai/glm-5.1";
            "minimax-m2.7".path = "minimaxai/minimax-m2.7";
            "kimi-k2.5".path = "moonshotai/kimi-k2.5";
            "qwen3.5-397b-a17b".path = "qwen/qwen3.5-397b-a17b";
          };
        };
      };

      # Computed outputs
      byProvider = registry;
      all = flatModels;
      textGenerationModels = builtins.filter (
        m:
        builtins.elem m.litellmModelInfo.mode [
          "chat"
          "responses"
        ]
      ) flatModels;
    };
  };
}
