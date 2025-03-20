{ config, ... }:
let
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  location = config.resource.azurerm_resource_group.celestia.location;
in
{
  resource = {
    # Store provisioning resources
    azurerm_storage_account.constellation = {
      name = "constellation";
      inherit resource_group_name location;
      account_tier = "Standard";
      account_replication_type = "LRS";
      allow_nested_items_to_be_public = false;
      blob_properties.last_access_time_enabled = true;
    };

    azurerm_storage_container = with config.resource; {
      # Bootstrap images for lumine
      constellation-lumine = {
        name = "lumine";
        storage_account_id = azurerm_storage_account.constellation "id";
        container_access_type = "private";
      };
    };
  };
}
