{ config, ... }: {
  resource = {
    # Virtual network
    azurerm_virtual_network.celestia-vnet = {
      name = "celestia-vnet";
      resource_group_name = config.resource.azurerm_resource_group.celestia.name;
      location = config.resource.azurerm_resource_group.celestia.location;
      address_space = [ "192.168.64.0/22" "fd00:c0d9:1c64::/46" ];
    };

    # Subnet
    azurerm_subnet.celestia-subnet = {
      name = "celestia-subnet";
      resource_group_name = config.resource.azurerm_resource_group.celestia.name;
      virtual_network_name = config.resource.azurerm_virtual_network.celestia-vnet.name;
      address_prefixes = [ "192.168.64.0/24" "fd00:c0d9:1c64::/64" ];
    };
  };
}
