{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-image-2 = {
    name = "gpt-image-2";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-image-2";
      version = "2026-04-21";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 9;
    };
  };
}
