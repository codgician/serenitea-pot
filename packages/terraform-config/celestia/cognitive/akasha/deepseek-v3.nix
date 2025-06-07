{ config, ... }:
{
  # Not supported by azurerm module yet
  # todo: migrate to azurerm_cognitive_deployment when the API exists preview
  resource.azapi_resource.akasha-deepseek-v3 = {
    type = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01";
    name = "deepseek-v3";
    parent_id = config.resource.azurerm_ai_services.akasha "id";
    body = {
      properties = {
        model = {
          format = "DeepSeek";
          name = "DeepSeek-V3-0324";
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
