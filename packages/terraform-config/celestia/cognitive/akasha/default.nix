{ config, lib, ... }:
let
  metadata = import ./models.nix;
  inherit (metadata) account deployments;
  inherit (account) location;
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;

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
