{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-kimi-k2-6 = {
    name = "kimi-k2.6";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "MoonshotAI";
      name = "Kimi-K2.6";
      version = "2026-04-20";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
