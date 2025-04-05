{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4-5 = {
    name = "gpt-4.5";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-4.5-preview";
      version = "2025-02-27";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 50;
    };
  };
}
