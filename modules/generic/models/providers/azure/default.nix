{
  config,
  lib,
  modelLib,
  outputs,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (modelLib) commonOptions;
  terraformConf =
    builtins.fromJSON
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.value;
  azureSubdomain = terraformConf.resource.azurerm_cognitive_account.akasha.custom_subdomain_name;
  deployedModelNames = lib.mapAttrsToList (_: value: value.name) (
    terraformConf.resource.azurerm_cognitive_deployment or { }
  );
  modelType = types.submodule {
    options = commonOptions // {
      provider = mkOption {
        type = types.enum [
          "azure"
          "azure_ai"
        ];
        default = "azure";
      };
      baseModel = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      apiVersion = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
  missingModels = lib.filter (name: !(builtins.elem name deployedModelNames)) (
    lib.attrNames config.codgician.models.providers.azure.models
  );
in
{
  description = "Azure AI models";
  inherit modelType;
  assertions = [
    {
      assertion = missingModels == [ ];
      message = "Azure models not in Terraform: ${builtins.concatStringsSep ", " missingModels}";
    }
  ];
  provider = {
    transformer = name: spec: {
      inherit (spec) aliases mode variants;
      reasoningEfforts = lib.unique (spec.reasoningEfforts ++ builtins.attrNames spec.variants);
      litellmModelInfo = {
        inherit (spec) mode;
      }
      // lib.optionalAttrs (spec.baseModel != null) { base_model = spec.baseModel; };
      litellmParams = {
        model = "${spec.provider}/${if spec.path != null then spec.path else name}";
        api_base = "https://${azureSubdomain}.services.ai.azure.com";
        api_key = "os.environ/AZURE_AKASHA_API_KEY";
      }
      // lib.optionalAttrs (spec.apiVersion != null) { api_version = spec.apiVersion; };
      tags = [
        "azure"
        "remote"
      ];
    };
    models = {
      "deepseek-v4-flash".provider = "azure_ai";
      "deepseek-v4-pro".provider = "azure_ai";
      "grok-4.3".provider = "azure_ai";
      "kimi-k2.6".provider = "azure_ai";
      "flux-2-pro" = {
        provider = "azure_ai";
        mode = "image_generation";
        baseModel = "azure_ai/FLUX.2-pro";
      };
      "gpt-image-2" = {
        mode = "image_generation";
        apiVersion = "2025-04-01-preview";
      };
    };
  };
}
