{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-deepseek-r1 = {
    name = "deepseek-r1";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "DeepSeek";
      name = "DeepSeek-R1-0528";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 1;
    };
  };
}
