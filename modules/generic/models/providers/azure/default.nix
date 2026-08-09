{
  lib,
  modelLib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (modelLib) commonOptions;
  metadata = import ../../../../../packages/terraform-config/celestia/cognitive/akasha/models.nix;
  azureSubdomain = metadata.account.name;
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
      realtimeProtocol = mkOption {
        type = types.nullOr (
          types.enum [
            "GA"
            "beta"
          ]
        );
        default = null;
      };
    };
  };
in
{
  description = "Azure AI models";
  inherit modelType;
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
      // lib.optionalAttrs (spec.realtimeProtocol != null) { realtime_protocol = spec.realtimeProtocol; }
      // lib.optionalAttrs (spec.apiVersion != null) { api_version = spec.apiVersion; };
      tags = [
        "azure"
        "remote"
      ];
    };
    models = lib.mapAttrs (_: deployment: deployment.registry) metadata.deployments;
  };
}
