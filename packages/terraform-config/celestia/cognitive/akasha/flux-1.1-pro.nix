{ config, ... }:
{
  # Not supported by azurerm module yet
  # todo: migrate to azurerm_cognitive_deployment when the API exists preview
  resource.azapi_resource.flux-1-1-pro = {
    type = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01";
    name = "flux-1.1-pro";
    parent_id = config.resource.azurerm_ai_services.akasha "id";
    body = {
      properties = {
        model = {
          format = "Black Forest Labs";
          name = "FLUX-1.1-pro";
          version = "1";
        };
        versionUpgradeOption = "OnceNewDefaultVersionAvailable";
        raiPolicyName = "Microsoft.DefaultV2";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 1000;
      };
    };
  };
}
