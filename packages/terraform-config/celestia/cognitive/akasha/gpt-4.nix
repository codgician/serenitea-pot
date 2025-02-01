{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4 = {
    name = "gpt-4";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.Default";

    model = {
      format = "OpenAI";
      name = "gpt-4";
      version = "turbo-2024-04-09";
    };

    sku = {
      name = "Standard";
      capacity = 30;
    };
  };
}
