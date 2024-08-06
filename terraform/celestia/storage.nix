{ config, ... }: 
let
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
  location = config.resource.azurerm_resource_group.celestia.location;
in
{
  resource = {
    # Storage accounts
    azurerm_storage_account = {
      # Boot diagnostics
      constellation = {
        name = "constellation";
        inherit resource_group_name location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        public_network_access_enabled = false;
        allow_nested_items_to_be_public = false;
      };

      # Resources needed for provisioning
      gnosis = {
        name = "gnosis";
        inherit resource_group_name location;
        account_tier = "Standard";
        account_replication_type = "LRS";
        public_network_access_enabled = false;
        allow_nested_items_to_be_public = false;
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
