{ config, ... }: {
  # Virtual machine image
  resource.azurerm_image.lumine-image = {
    name = "lumine-image";
    location = config.resource.azurerm_resource_group.celestia.location;
    resource_group_name = config.resource.azurerm_resource_group.celestia.name;
    hyper_v_generation = "V2";

    os_disk = [{
      os_type = "Linux";
      os_state = "Generalized";
      blob_uri = "${config.resource.azurerm_storage_account.gnosis "primary_blob_endpoint"}${config.resource.azurerm_storage_container.gnosis-lumine.name}/nixos.vhd";
      size_gb = 32;
    }];
  };
}
