{ config, ... }:
{
  imports = [
    ./gpt-4.nix
    ./gpt-4o.nix
    ./gpt-4o-realtime.nix
  ];

  resource.azurerm_ai_services.akasha = rec {
    name = "akasha";
    custom_subdomain_name = name;
    public_network_access = "Enabled";
    location = "eastus2";
    resource_group_name = config.resource.azurerm_resource_group.celestia.name;
    sku_name = "S0";
  };
}
