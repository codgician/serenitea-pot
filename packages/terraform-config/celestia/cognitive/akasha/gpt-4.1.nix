{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4-1 = {
    name = "gpt-4.1";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-4.1";
      version = "2025-04-14";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 50;
    };
  };
}
