{
  lib,
  modelLib,
  ...
}:
let
  metadata = import ../../../../../packages/terraform-config/celestia/cognitive/akasha/models.nix;
in
{
  provider = {
    transformer =
      name: spec:
      modelLib.mkModel {
        modelPrefix = spec.provider or "azure";
        apiKeyEnv = "AZURE_AKASHA_API_KEY";
        tags = [
          "azure"
          "remote"
        ];
        extraKeys = [
          "provider"
          "baseModel"
          "realtimeProtocol"
          "apiVersion"
        ];
        extraModelInfo = lib.optionalAttrs (spec ? baseModel) { base_model = spec.baseModel; };
        extraParams = {
          api_base = "https://${metadata.account.name}.services.ai.azure.com";
        }
        // lib.optionalAttrs (spec ? realtimeProtocol) { realtime_protocol = spec.realtimeProtocol; }
        // lib.optionalAttrs (spec ? apiVersion) { api_version = spec.apiVersion; };
      } name spec;
    models = lib.mapAttrs (_: deployment: deployment.registry) (
      lib.filterAttrs (_: deployment: deployment ? registry) metadata.deployments
    );
  };
}
