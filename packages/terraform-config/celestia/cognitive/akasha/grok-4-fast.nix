{ config, ... }:
{
  resource.azurerm_cognitive_deployment = {
    akasha-grok-4-fast-reasoning = {
      name = "grok-4-fast-reasoning";
      cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
      version_upgrade_option = "OnceNewDefaultVersionAvailable";
      rai_policy_name = "Microsoft.DefaultV2";

      model = {
        format = "xAI";
        name = "grok-4-fast-reasoning";
        version = "1";
      };

      sku = {
        name = "GlobalStandard";
        capacity = 50;
      };
    };

    akasha-grok-4-fast-non-reasoning = {
      name = "grok-4-fast-non-reasoning";
      cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
      version_upgrade_option = "OnceNewDefaultVersionAvailable";
      rai_policy_name = "Microsoft.DefaultV2";

      model = {
        format = "xAI";
        name = "grok-4-fast-non-reasoning";
        version = "1";
      };

      sku = {
        name = "GlobalStandard";
        capacity = 50;
      };
    };
  };
}
