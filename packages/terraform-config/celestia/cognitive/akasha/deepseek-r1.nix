{ config, ... }:
{
  # Not supported by azurerm module yet
  # todo: migrate to azurerm_cognitive_deployment when the API exists preview
  resource.azapi_resource.akasha-deepseek-r1 = {
    type = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01";
    name = "deepseek-r1";
    parent_id = config.resource.azurerm_ai_services.akasha "id";
    body = {
      properties = {
        model = {
          format = "DeepSeek";
          name = "DeepSeek-R1-0528";
          version = "1";
        };
        versionUpgradeOption = "OnceNewDefaultVersionAvailable";
        raiPolicyName = "Microsoft.DefaultV2";
      };
      sku = {
        name = "GlobalStandard";
        capacity = 1;
      };
    };
  };
}
