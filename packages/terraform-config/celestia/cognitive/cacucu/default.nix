{ config, ... }:
let
  location = "japaneast";
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
in
{
  resource.azurerm_cognitive_account.cacucu = rec {
    name = "cacucu";
    inherit location resource_group_name;
    kind = "SpeechServices";
    public_network_access_enabled = true;
    custom_subdomain_name = name;
    sku_name = "S0";
  };
}
