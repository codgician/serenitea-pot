{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-o3-mini = {
    name = "o3-mini";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "o3-mini";
      version = "2025-01-31";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 1;
    };
  };
}
