{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-o4-mini = {
    name = "o4-mini";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "o4-mini";
      version = "2025-04-16";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 150;
    };
  };
}
