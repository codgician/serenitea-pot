{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4o-realtime = {
    name = "akasha-gpt-4o-realtime";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.Default";

    model = {
      format = "OpenAI";
      name = "gpt-4o-realtime-preview";
      version = "2024-10-01";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 1;
    };
  };
}
