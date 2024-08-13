{ config, ... }:
let
  location = config.resource.azurerm_resource_group.celestia.location;
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
in
{
  resource = {
    # Virtual machine image
    azurerm_image.lumine-image = {
      name = "lumine-image";
      inherit location resource_group_name;
      hyper_v_generation = "V2";

      os_disk = with config.resource; [{
        os_type = "Linux";
        os_state = "Generalized";
        blob_uri = "${azurerm_storage_account.constellation "primary_blob_endpoint"}${azurerm_storage_container.constellation-lumine.name}/sda.vhd";
        size_gb = 48;
      }];

      depends_on = [ "azurerm_storage_container.constellation-lumine" ];
    };

    # Shared image
    azurerm_shared_image.lumine-nixos = with config.resource; {
      name = "lumine-nixos";
      gallery_name = azurerm_shared_image_gallery.gnosis.name;
      inherit location resource_group_name;
      os_type = "Linux";

      architecture = "x64";
      hyper_v_generation = "V2";
      accelerated_network_support_enabled = true;
      trusted_launch_supported = true;

      identifier = {
        publisher = "codgician";
        offer = "NixOS";
        sku = "lumine";
      };
    };

    azurerm_shared_image_version.lumine-1 = with config.resource; {
      name = "1.0.0";
      gallery_name = azurerm_shared_image_gallery.gnosis.name;
      image_name = azurerm_shared_image.lumine-nixos.name;
      inherit location resource_group_name;
      managed_image_id = azurerm_image.lumine-image "id";

      target_region = {
        name = azurerm_resource_group.celestia.location;
        regional_replica_count = 1;
      };

      depends_on = [ "azurerm_image.lumine-image" ];
    };
  };
}
