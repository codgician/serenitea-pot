{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-deepseek-v3-2-speciale = {
    name = "deepseek-v3.2-speciale";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "DeepSeek";
      name = "DeepSeek-V3.2-Speciale";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 20;
    };
  };
}
