{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-deepseek-v4-pro = {
    name = "deepseek-v4-pro";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "DeepSeek";
      name = "DeepSeek-V4-Pro";
      version = "2026-04-23";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
