{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-sora = {
    name = "sora";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "sora";
      version = "2025-05-02";
    };

    sku = {
      name = "Standard";
      capacity = 60;
    };
  };
}
