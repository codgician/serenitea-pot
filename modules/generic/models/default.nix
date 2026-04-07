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
  };

  # ===========================================================================
  # Provider-specific model types (extending common options)
  # ===========================================================================

  # Basic type for simple providers (anthropic, chatgpt, deepseek, google)
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

  # GitHub: no additional options, but kept separate for clarity
  githubModelType = types.submodule {
    options = commonOptions;
  };

  # NVIDIA: adds required path for NIM
  nvidiaModelType = types.submodule {
    options = commonOptions // {
      path = mkOption {
        type = types.str;
        description = "Full model path on NVIDIA NIM (e.g., 'z-ai/glm5')";
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

  # Shared helper for providers using common options
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
        base_model = "${modelPrefix}/${name}";
      }
      // extraModelInfo;
      litellmParams = {
        model = "${modelPrefix}/${name}";
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
  claudeSonnet46 = {
    high.output_config.effort = "high";
    medium.output_config.effort = "medium";
    low.output_config.effort = "low";
  };

  # Claude Opus 4.6 extends Sonnet 4.6 with max effort
  claudeOpus46 = claudeSonnet46 // {
    max.output_config.effort = "max";
  };

  # Opus 4.5 and Sonnet 4.5 use manual thinking (budget_tokens)
  claude45 = {
    high.thinking = {
      type = "enabled";
      budget_tokens = 16000;
    };
    max.thinking = {
      type = "enabled";
      budget_tokens = 31999;
    };
  };

  # GPT-5.x reasoning effort variants
  gpt5 = {
    high = {
      reasoningEffort = "high";
      textVerbosity = "high";
    };
    medium.reasoningEffort = "medium";
    low.reasoningEffort = "low";
    minimal.reasoningEffort = "minimal";
    none.reasoningEffort = "none";
  };

  # GPT-5.2+ adds xhigh reasoning
  gpt52 = gpt5 // {
    xhigh = {
      reasoningEffort = "xhigh";
      textVerbosity = "high";
    };
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
        type = mkProviderType githubModelType;
        description = "GitHub Copilot models";
      };
      nvidia = mkOption {
        type = mkProviderType nvidiaModelType;
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
            # Opus 4.6 supports effort-based control (including max effort)
            "claude-opus-4-6" = {
              aliases = [ "claude-opus-4.6" ];
              variants = claudeOpus46;
            };
            # Opus 4.5 uses manual thinking with budget_tokens
            "claude-opus-4-5" = {
              aliases = [ "claude-opus-4.5" ];
              variants = claude45;
            };
            # Haiku doesn't support extended thinking
            "claude-haiku-4-5".aliases = [ "claude-haiku-4.5" ];
            # Sonnet 4.6 supports effort-based control (no max effort)
            "claude-sonnet-4-6" = {
              aliases = [ "claude-sonnet-4.6" ];
              variants = claudeSonnet46;
            };
            # Sonnet 4.5 uses manual thinking with budget_tokens
            "claude-sonnet-4-5" = {
              aliases = [ "claude-sonnet-4.5" ];
              variants = claude45;
            };
          };
        };

        # Azure models
        azure = {
          transformer = name: spec: {
            inherit (spec) aliases mode variants;
            litellmModelInfo = {
              inherit (spec) mode;
              base_model = if spec.baseModel != null then spec.baseModel else "${spec.provider}/${name}";
            };
            litellmParams = {
              model = "${spec.provider}/${name}";
              api_base = "https://${azureSubdomain}.services.ai.azure.com";
              api_key = "os.environ/AZURE_AKASHA_API_KEY";
            };
            tags = [ "azure" ];
          };
          models = {
            # Azure AI provider - chat models
            "deepseek-v3.2".provider = "azure_ai";
            "deepseek-v3.2-speciale".provider = "azure_ai";
            "grok-4-1-fast-non-reasoning".provider = "azure_ai";
            "grok-4-1-fast-reasoning".provider = "azure_ai";
            "kimi-k2.5".provider = "azure_ai";

            # Azure AI provider - image generation
            "flux-1-1-pro" = {
              provider = "azure_ai";
              mode = "image_generation";
              baseModel = "azure_ai/FLUX-1.1-pro";
            };
            "flux-1-kontext-pro" = {
              provider = "azure_ai";
              mode = "image_generation";
              baseModel = "azure_ai/FLUX.1-Kontext-pro";
            };

            # Azure provider - OpenAI models
            "gpt-4o-transcribe-diarize".mode = "audio_transcription";
            "gpt-5.3-chat" = { };
            "gpt-5.2-chat" = { };
            "gpt-5.1-chat" = { };
            "gpt-5-nano" = { };
            "gpt-audio-1.5".baseModel = "azure/gpt-audio-1.5-2026-02-23";
            "gpt-realtime-1.5" = {
              mode = "realtime";
              baseModel = "azure/gpt-realtime-1.5-2026-02-23";
            };
            "o4-mini" = { };
          };
        };

        # ChatGPT models
        chatgpt = {
          transformer = mkModel {
            modelPrefix = "chatgpt";
            tags = [ "chatgpt" ];
          };
          models = {
            "gpt-5.4" = {
              mode = "responses";
              variants = gpt52;
            };
            "gpt-5.3-codex" = {
              mode = "responses";
              variants = gpt52;
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
            "deepseek-chat" = { };
            "deepseek-reasoner" = { };
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
              editor-version = "vscode/${pkgs.vscode.version}";
              editor-plugin-version = "copilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
              user-agent = "GithubCopilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
              Copilot-Vision-Request = "true";
            };
          };
          models = {
            # Embedding models
            "text-embedding-3-small".mode = "embedding";
            "text-embedding-3-small-inference".mode = "embedding";
            "text-embedding-ada-002".mode = "embedding";

            # Gemini models
            "gemini-3-flash-preview" = { };
            "gemini-3.1-pro-preview".variants = geminiPro;

            # GPT-5.x chat models
            "gpt-5.1".variants = gpt5;
            "gpt-5.2".variants = gpt52;

            # GPT-5.x codex models (responses mode)
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
              variants = gpt52;
            };
          };
        };

        # NVIDIA NIM models
        nvidia = {
          transformer = name: spec: {
            inherit (spec) aliases mode variants;
            litellmModelInfo.mode = "chat";
            litellmParams = {
              model = "nvidia_nim/${spec.path}";
              api_key = "os.environ/NVIDIA_NIM_API_KEY";
            };
            tags = [ "nvidia" ];
          };
          models = {
            "glm5".path = "z-ai/glm5";
            "minimax-m2.5".path = "minimaxai/minimax-m2.5";
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
