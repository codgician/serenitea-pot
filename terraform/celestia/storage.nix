{ config, ... }: {
  resource = {
    # Storage accounts
    azurerm_storage_account = {
      # Boot diagnostics
      constellation = {
        name = "constellation";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        allow_nested_items_to_be_public = false;
      };

      # Resources needed for provisioning
      gnosis = {
        name = "gnosis";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        allow_nested_items_to_be_public = true;
      };
    };

    # Storage account containers
    azurerm_storage_container = {
      gnosis-lumine = {
        name = "lumine";
        storage_account_name = config.resource.azurerm_storage_account.gnosis.name;
        container_access_type = "blob";
      };
    };
  };
}
