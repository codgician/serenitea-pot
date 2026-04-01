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
  # Variant Definitions (shared across providers)
  # ===========================================================================
  variants = {
    claude = {
      high.thinking = {
        type = "enabled";
        budget_tokens = 16000;
      };
      max.thinking = {
        type = "enabled";
        budget_tokens = 31999;
      };
    };
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
    gpt52 = variants.gpt5 // {
      xhigh = {
        reasoningEffort = "xhigh";
        textVerbosity = "high";
      };
    };
    geminiPro = {
      high.reasoningEffort = "high";
      low.reasoningEffort = "low";
    };
  };

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
  # Provider-specific submodule types (extending common options)
  # ===========================================================================

  # Basic type for simple providers (anthropic, deepseek, google)
  basicModelType = types.submodule {
    options = commonOptions;
  };

  # Azure: adds provider backend selection and baseModel override
  azureModelType = types.submodule {
    options = commonOptions // {
      provider = mkOption {
        type = types.enum [ "azure" "azure_ai" ];
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
    name: spec:
    {
      inherit (spec) aliases mode variants;
      litellmModelInfo = {
        inherit (spec) mode;
        base_model = "${modelPrefix}/${name}";
      } // extraModelInfo;
      litellmParams =
        { model = "${modelPrefix}/${name}"; }
        // lib.optionalAttrs (apiKeyEnv != null) { api_key = "os.environ/${apiKeyEnv}"; }
        // extraParams;
      inherit tags;
    };

  # Provider-specific transformers
  mkAnthropicModel =
    name: spec:
    let
      isHaiku = lib.hasInfix "haiku" name;
    in
    mkModel {
      modelPrefix = "anthropic";
      apiKeyEnv = "ANTHROPIC_API_KEY";
      tags = [ "anthropic" ];
      extraParams = {
        extra_headers = {
          "User-Agent" = "claude-cli/${pkgs.claude-code.version} (external, cli)";
          "anthropic-beta" =
            "oauth-2025-04-20,interleaved-thinking-2025-05-14,claude-code-20250219,context-1m-2025-08-07,fine-grained-tool-streaming-2025-05-14";
        };
      } // lib.optionalAttrs (!isHaiku) { prompt_id = "claude-code"; };
    } name spec;

  mkAzureModel = name: spec: {
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

  mkDeepseekModel = mkModel {
    modelPrefix = "deepseek";
    apiKeyEnv = "DEEPSEEK_API_KEY";
    tags = [ "deepseek" ];
  };

  mkGoogleModel =
    name: spec:
    mkModel {
      modelPrefix = "gemini";
      apiKeyEnv = "GEMINI_API_KEY";
      tags = [ "google" ];
    } name (spec // { mode = "image_generation"; });

  mkGithubModel = mkModel {
    modelPrefix = "github_copilot";
    tags = [ "github" ];
    extraParams.extra_headers = {
      editor-version = "vscode/${pkgs.vscode.version}";
      editor-plugin-version = "copilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
      user-agent = "GithubCopilot/${pkgs.vscode-marketplace-release.github.copilot.version}";
      Copilot-Vision-Request = "true";
    };
  };

  mkNvidiaModel = name: spec: {
    inherit (spec) aliases mode variants;
    litellmModelInfo.mode = "chat";
    litellmParams = {
      model = "nvidia_nim/${spec.path}";
      api_key = "os.environ/NVIDIA_NIM_API_KEY";
    };
    tags = [ "nvidia" ];
  };

  # ===========================================================================
  # Build Registry from typed config
  # ===========================================================================

  transformers = {
    anthropic = mkAnthropicModel;
    azure = mkAzureModel;
    deepseek = mkDeepseekModel;
    google = mkGoogleModel;
    github = mkGithubModel;
    nvidia = mkNvidiaModel;
  };

  registry = lib.mapAttrs (provider: mkFn: lib.mapAttrs mkFn cfg.providers.${provider}) transformers;

  # Azure Terraform validation (validate directly from input config)
  missingAzureModels = lib.filter (name: !(builtins.elem name deployedModelNames)) (
    lib.attrNames cfg.providers.azure
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
  imports = [ ./list.nix ];

  options.codgician.models = {
    # Provider specifications (typed inputs)
    providers = {
      anthropic = mkOption {
        type = types.attrsOf basicModelType;
        default = { };
        description = "Anthropic Claude models";
      };
      azure = mkOption {
        type = types.attrsOf azureModelType;
        default = { };
        description = "Azure AI models";
      };
      deepseek = mkOption {
        type = types.attrsOf basicModelType;
        default = { };
        description = "DeepSeek models";
      };
      google = mkOption {
        type = types.attrsOf basicModelType;
        default = { };
        description = "Google Gemini models";
      };
      github = mkOption {
        type = types.attrsOf githubModelType;
        default = { };
        description = "GitHub Copilot models";
      };
      nvidia = mkOption {
        type = types.attrsOf nvidiaModelType;
        default = { };
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
    variants = mkOption {
      type = variantsType;
      readOnly = true;
      description = "Shared variant definitions for use in provider configs";
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
      inherit variants;
      byProvider = registry;
      all = flatModels;
      textGenerationModels = builtins.filter (
        m: builtins.elem m.litellmModelInfo.mode [ "chat" "responses" ]
      ) flatModels;
    };
  };
}
