{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4o-mini = {
    name = "gpt-4o-mini";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-4o-mini";
      version = "2024-07-18";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 200;
    };
  };
}
