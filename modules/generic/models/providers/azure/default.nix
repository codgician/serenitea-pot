{
  lib,
  modelLib,
  ...
}:
let
  inherit (lib) mkOption types;
  metadata = import ../../../../../packages/terraform-config/celestia/cognitive/akasha/models.nix;
in
{
  description = "Azure AI models";
  modelType = types.submodule {
    options = modelLib.commonOptions // {
      provider = mkOption {
        type = types.enum [
          "azure"
          "azure_ai"
        ];
        default = "azure";
        description = "LiteLLM provider the deployment is called through.";
      };
      baseModel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Model LiteLLM takes prices and limits from.";
      };
      apiVersion = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Azure API version, where the deployment needs a particular one.";
      };
      realtimeProtocol = mkOption {
        type = types.nullOr (
          types.enum [
            "GA"
            "beta"
          ]
        );
        default = null;
        description = "Protocol of a realtime deployment.";
      };
    };
  };
  provider = {
    transformer =
      name: spec:
      modelLib.mkModel {
        modelPrefix = spec.provider;
        apiKeyEnv = "AZURE_AKASHA_API_KEY";
        tags = [
          "azure"
          "remote"
        ];
        extraModelInfo = lib.optionalAttrs (spec.baseModel != null) { base_model = spec.baseModel; };
        extraParams = {
          api_base = "https://${metadata.account.name}.services.ai.azure.com";
        }
        // lib.optionalAttrs (spec.realtimeProtocol != null) {
          realtime_protocol = spec.realtimeProtocol;
        }
        // lib.optionalAttrs (spec.apiVersion != null) { api_version = spec.apiVersion; };
      } name spec;
    models = lib.mapAttrs (_: deployment: deployment.registry) (
      lib.filterAttrs (_: deployment: deployment ? registry) metadata.deployments
    );
  };
}
