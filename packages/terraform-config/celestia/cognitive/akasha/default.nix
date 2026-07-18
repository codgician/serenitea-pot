{ config, ... }:
let
  location = "swedencentral";
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  cognitive_account_id =
    "/subscriptions/"
    + config.provider.azurerm.subscription_id
    + "/resourceGroups/celestia/providers/Microsoft.CognitiveServices/accounts/akasha";
in
{
  imports = [
    ./deepseek-v4-flash.nix
    ./deepseek-v4-pro.nix
    ./flux.2-pro.nix
    ./gpt-4o-transcribe-diarize.nix
    ./gpt-5.4-nano.nix
    ./gpt-5.4-pro.nix
    ./gpt-image-2.nix
    ./grok-4.3.nix
    ./kimi-k2.6.nix
  ];

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
    azurerm_cognitive_account.akasha = rec {
      name = "akasha";
      custom_subdomain_name = name;
      identity.type = "SystemAssigned";
      kind = "AIServices";
      inherit location resource_group_name;
      project_management_enabled = true;
      public_network_access_enabled = true;
      sku_name = "S0";
    };

    azurerm_cognitive_account_project.akasha = {
      name = "akasha";
      cognitive_account_id = config.resource.azurerm_cognitive_account.akasha "id";
      inherit location;
      identity.type = "SystemAssigned";
    };
  };
}
