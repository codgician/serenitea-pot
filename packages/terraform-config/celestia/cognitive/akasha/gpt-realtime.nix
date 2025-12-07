{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-realtime = {
    name = "gpt-realtime";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-realtime";
      version = "2025-08-28";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 10;
    };
  };
}
