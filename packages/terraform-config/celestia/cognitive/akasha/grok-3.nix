{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-grok-3 = {
    name = "grok-3";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "xAI";
      name = "grok-3";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 50;
    };
  };
}
