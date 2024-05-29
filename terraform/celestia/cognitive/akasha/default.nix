{ config, ... }: {
  imports = [
    ./gpt-4o.nix
  ];

  resource.azurerm_cognitive_account.akasha = rec {
    name = "akasha";
    custom_subdomain_name = name;
    location = "eastus2";
    resource_group_name = config.resource.azurerm_resource_group.celestia.name;
    kind = "OpenAI";
    sku_name = "S0";
  };
}
