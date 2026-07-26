{ config, lib, ... }:
let
  metadata = import ./models.nix;
  inherit (metadata) account deployments;
  inherit (account) location;
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  cognitive_account_id =
    "/subscriptions/"
    + config.provider.azurerm.subscription_id
    + "/resourceGroups/celestia/providers/Microsoft.CognitiveServices/accounts/${account.name}";

  deploymentResources = lib.mapAttrs' (
    name: deployment:
    lib.nameValuePair "${account.name}-${lib.replaceStrings [ "." ] [ "-" ] name}" {
      inherit name;
      cognitive_account_id = config.resource.azurerm_cognitive_account.akasha "id";
      version_upgrade_option = "OnceNewDefaultVersionAvailable";
      rai_policy_name = "Microsoft.DefaultV2";
      inherit (deployment) model sku;
    }
  ) deployments;
in
{
  # Preserve the existing account while changing from the deprecated resource type.
  removed = [
    {
      from = "azurerm_ai_services.akasha";
      lifecycle.destroy = false;
    }
  ];

  import = [
    {
      to = "azurerm_cognitive_account.akasha";
      id = cognitive_account_id;
    }
  ];

  resource = {
    azurerm_cognitive_account.akasha = {
      inherit (account) name;
      custom_subdomain_name = account.name;
      identity.type = "SystemAssigned";
      kind = "AIServices";
      inherit location resource_group_name;
      project_management_enabled = true;
      public_network_access_enabled = true;
      sku_name = "S0";
    };

    azurerm_cognitive_account_project.akasha = {
      inherit (account) name;
      cognitive_account_id = config.resource.azurerm_cognitive_account.akasha "id";
      inherit location;
      identity.type = "SystemAssigned";
    };

    azurerm_cognitive_deployment = deploymentResources;
  };
}
