{ config, ... }:
let
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  location = config.resource.azurerm_resource_group.celestia.location;
in
{
  resource = {
    # Storage accounts
    azurerm_storage_account = {
      # Resources needed for provisioning
      constellation = {
        name = "constellation";
        inherit resource_group_name location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        allow_nested_items_to_be_public = false;
      };

      # Binary cache
      primogems = {
        name = "primogems";
        inherit resource_group_name location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        allow_nested_items_to_be_public = true;
      };
    };

    # Storage account containers
    azurerm_storage_container = with config.resource; {
      # Bootstrap images for lumine
      constellation-lumine = {
        name = "lumine";
        storage_account_name = azurerm_storage_account.constellation.name;
        container_access_type = "private";
      };

      # Binary cache for serenitea pot
      serenitea-pot = {
        name = "serenitea-pot";
        storage_account_name = azurerm_storage_account.primogems.name;
        container_access_type = "blob";
      };
    };
  };
}
