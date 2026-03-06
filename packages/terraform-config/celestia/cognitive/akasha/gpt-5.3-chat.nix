{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-5-3-chat = {
    name = "gpt-5.3-chat";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-5.3-chat";
      version = "2026-03-03";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 50;
    };
  };
}
