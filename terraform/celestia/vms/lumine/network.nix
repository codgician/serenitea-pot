{ config, ... }: {
  resource = {
    # Public IP prefixes 
    azurerm_public_ip_prefix = {
      lumine-ipv4-prefix = {
        name = "lumine-ipv4-prefix";
        location = config.resource.azurerm_resource_group.celestia.location;
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        ip_version = "IPv4";
        prefix_length = 31;
        sku = "Standard";
      };

      lumine-ipv6-prefix = {
        name = "lumine-ipv6-prefix";
        location = config.resource.azurerm_resource_group.celestia.location;
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        ip_version = "IPv6";
        prefix_length = 127;
        sku = "Standard";
      };
    };

    # Public IP addresses
    azurerm_public_ip = {
      lumine-ipv4-1 = {
        name = "lumine-ipv4-1";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        allocation_method = "Static";
        public_ip_prefix_id = config.resource.azurerm_public_ip_prefix.lumine-ipv4-prefix "id";
        ip_version = "IPv4";
        sku = "Standard";
        idle_timeout_in_minutes = 30;
      };

      lumine-ipv6-1 = {
        name = "lumine-ipv6-1";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        allocation_method = "Static";
        public_ip_prefix_id = config.resource.azurerm_public_ip_prefix.lumine-ipv6-prefix "id";
        ip_version = "IPv6";
        sku = "Standard";
        idle_timeout_in_minutes = 30;
      };

      lumine-ipv4-2 = {
        name = "lumine-ipv4-2";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        allocation_method = "Static";
        public_ip_prefix_id = config.resource.azurerm_public_ip_prefix.lumine-ipv4-prefix "id";
        ip_version = "IPv4";
        sku = "Standard";
        idle_timeout_in_minutes = 30;
      };

      lumine-ipv6-2 = {
        name = "lumine-ipv6-2";
        resource_group_name = config.resource.azurerm_resource_group.celestia.name;
        location = config.resource.azurerm_resource_group.celestia.location;
        allocation_method = "Static";
        public_ip_prefix_id = config.resource.azurerm_public_ip_prefix.lumine-ipv6-prefix "id";
        ip_version = "IPv6";
        sku = "Standard";
        idle_timeout_in_minutes = 30;
      };
    };

    # Network security group
    azurerm_network_security_group.lumine-nsg = {
      name = "lumine-nsg";
      location = config.resource.azurerm_resource_group.celestia.location;
      resource_group_name = config.resource.azurerm_resource_group.celestia.name;

      security_rule = builtins.map
        (direction: {
          name = "Allow-All-${direction}";
          description = "Allow all ${direction}s.";
          priority = 100;
          inherit direction;
          access = "Allow";
          protocol = "*";
          source_port_range = "*";
          destination_port_range = "*";
          source_address_prefix = "*";
          destination_address_prefix = "*";
          destination_address_prefixes = "\${null}";
          destination_application_security_group_ids = "\${null}";
          destination_port_ranges = "\${null}";
          source_address_prefixes = "\${null}";
          source_application_security_group_ids = "\${null}";
          source_port_ranges = "\${null}";
        }) [ "Inbound" "Outbound" ];
    };

    # Network interface
    azurerm_network_interface.lumine-netint = {
      name = "lumine-netint";
      location = config.resource.azurerm_resource_group.celestia.location;
      resource_group_name = config.resource.azurerm_resource_group.celestia.name;
      accelerated_networking_enabled = false;

      ip_configuration = [
        {
          name = "ipv4cfg-1";
          subnet_id = config.resource.azurerm_subnet.celestia-subnet "id";
          public_ip_address_id = config.resource.azurerm_public_ip.lumine-ipv4-2 "id";
          primary = true;
          private_ip_address_allocation = "Dynamic";
          private_ip_address_version = "IPv4";
        }
        {
          name = "ipv6cfg-1";
          subnet_id = config.resource.azurerm_subnet.celestia-subnet "id";
          public_ip_address_id = config.resource.azurerm_public_ip.lumine-ipv6-2 "id";
          private_ip_address_allocation = "Dynamic";
          private_ip_address_version = "IPv6";
        }
      ];
    };

    # Associations between azure network interface and security group
    azurerm_network_interface_security_group_association.lumine-netint-nsg = {
      network_interface_id = config.resource.azurerm_network_interface.lumine-netint "id";
      network_security_group_id = config.resource.azurerm_network_security_group.lumine-nsg "id";
    };
  };
}
