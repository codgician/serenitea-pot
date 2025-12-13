{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-kimi-k2-thinking = {
    name = "kimi-k2-thinking";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "MoonshotAI";
      name = "Kimi-K2-Thinking";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
