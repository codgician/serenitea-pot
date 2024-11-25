{ config, ... }:
let
  location = config.resource.azurerm_resource_group.celestia.location;
  resource_group_name = config.resource.azurerm_resource_group.celestia.name;
in
{
  resource = {
    # Image gallery: Gnosis
    azurerm_shared_image_gallery.gnosis = {
      name = "gnosis";
      inherit location resource_group_name;
      description = "Items used to reasonate with celestia.";
    };
  };
}
