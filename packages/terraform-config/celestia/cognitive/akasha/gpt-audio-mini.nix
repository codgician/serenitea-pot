{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-audio-mini = {
    name = "gpt-audio-mini";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-audio-mini";
      version = "2025-10-06";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 2;
    };
  };
}
