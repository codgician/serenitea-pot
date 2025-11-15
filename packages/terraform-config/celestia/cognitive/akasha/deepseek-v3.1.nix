{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-deepseek-v3-1 = {
    name = "deepseek-v3.1";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "DeepSeek";
      name = "DeepSeek-V3.1";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
