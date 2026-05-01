{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-deepseek-v4-flash = {
    name = "deepseek-v4-flash";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "DeepSeek";
      name = "DeepSeek-V4-Flash";
      version = "2026-04-23";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
