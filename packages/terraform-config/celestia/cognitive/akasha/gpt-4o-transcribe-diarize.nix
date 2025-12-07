{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-4o-transcribe-diarize = {
    name = "gpt-4o-transcribe-diarize";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI";
      name = "gpt-4o-transcribe-diarize";
      version = "2025-10-15";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 400;
    };
  };
}
