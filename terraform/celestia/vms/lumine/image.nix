{ config, ... }: {
  # Virtual machine image
  resource.azurerm_image.lumine-image = with config.resource; {
    name = "lumine-image";
    location = azurerm_resource_group.celestia.location;
    resource_group_name = azurerm_resource_group.celestia.name;
    hyper_v_generation = "V2";

    os_disk = [{
      os_type = "Linux";
      os_state = "Generalized";
      blob_uri = "${azurerm_storage_account.gnosis "primary_blob_endpoint"}${azurerm_storage_container.gnosis-lumine.name}/sda.vhd";
      size_gb = 48;
    }];
  };
}
