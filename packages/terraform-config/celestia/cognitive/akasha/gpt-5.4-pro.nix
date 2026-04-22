{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-5-4-pro = {
    name = "gpt-5.4-pro";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-5.4-pro";
      version = "2026-03-05";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 160;
    };
  };
}
