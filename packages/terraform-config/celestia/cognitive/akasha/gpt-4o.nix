{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4o = {
    name = "gpt-4o";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.Default";

    model = {
      format = "OpenAI";
      name = "gpt-4o";
      version = "2024-08-06";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 30;
    };
  };
}
