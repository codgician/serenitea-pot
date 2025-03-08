{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4o-realtime = {
    name = "gpt-4o-realtime";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-4o-realtime-preview";
      version = "2024-12-17";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 1;
    };
  };
}
