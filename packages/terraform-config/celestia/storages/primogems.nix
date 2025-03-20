{ config, ... }:
let
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  location = config.resource.azurerm_resource_group.celestia.location;
in
{
  resource = {
    # Binary cache
    azurerm_storage_account.primogems = {
      name = "primogems";
      inherit resource_group_name location;
      account_tier = "Standard";
      account_replication_type = "LRS";
      allow_nested_items_to_be_public = true;
      blob_properties.last_access_time_enabled = true;
    };

    azurerm_storage_container = with config.resource; {
      # Binary cache for serenitea pot
      serenitea-pot = {
        name = "serenitea-pot";
        storage_account_id = azurerm_storage_account.primogems "id";
        container_access_type = "blob";
      };
    };

    azurerm_storage_management_policy.primogems-gc = with config.resource; {
      storage_account_id = azurerm_storage_account.primogems "id";
      rule = [
        {
          enabled = true;
          name = "garbage-collection";
          filters.blob_types = [ "blockBlob" ];
          actions = {
            base_blob = {
              auto_tier_to_hot_from_cool_enabled = true;
              tier_to_cool_after_days_since_last_access_time_greater_than = 7;
              delete_after_days_since_last_access_time_greater_than = 14;
            };
          };
        }
      ];
    };
  };
}
