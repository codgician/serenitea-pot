{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-5-chat = {
    name = "gpt-5-chat";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-5-chat";
      version = "2025-08-07";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 50;
    };
  };
}
