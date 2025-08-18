{ config, ... }:
{
  resource.azurerm_cognitive_deployment.akasha-flux-1-1-pro = {
    name = "flux-1-1-pro";
    cognitive_account_id = config.resource.azurerm_ai_services.akasha "id";
    version_upgrade_option = "OnceNewDefaultVersionAvailable";
    rai_policy_name = "Microsoft.DefaultV2";

    model = {
      format = "Black Forest Labs";
      name = "FLUX-1.1-pro";
      version = "1";
    };

    sku = {
      name = "GlobalStandard";
      capacity = 6;
    };
  };
}
