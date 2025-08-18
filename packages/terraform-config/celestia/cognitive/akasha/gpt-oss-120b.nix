{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-gpt-oss-120b = {
    name = "gpt-oss-120b";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "OpenAI-OSS";
      name = "gpt-oss-120b";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 5000;
    };
  };
}
