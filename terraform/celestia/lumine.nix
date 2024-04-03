{ config, ... }: {
  resource = {

    # Ensure encryption at host feature is enabled
    # See https://github.com/hashicorp/terraform-provider-azurerm/issues/17185
    azapi_update_resource.encryptionAtHost = {
      type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01";
      resource_id = "/subscriptions/${config.provider.azapi.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Compute/subscriptionFeatureRegistrations/encryptionathost";
      body = builtins.toJSON { properties = {}; };
    };

    # Virtual machine image
    azurerm_image.lumine-image = {
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

    # Virtual machines
    azurerm_linux_virtual_machine.lumine = {
      name = "lumine";
      location = config.resource.azurerm_resource_group.celestia.location;
      resource_group_name = config.resource.azurerm_resource_group.celestia.name;
      network_interface_ids = with config.resource.azurerm_network_interface; [ (lumine-netint "id") ];
      size = "Standard_B2s";
      admin_username = "codgi";
      secure_boot_enabled = false;
      vtpm_enabled = false;
      source_image_id = config.resource.azurerm_image.lumine-image "id";
      encryption_at_host_enabled = true;

      # These keys are not used for actual authentication
      admin_ssh_key = [{
        username = "codgi";
        public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCWRfPygh33b7Kz0ljD9WN+nz6q5LHxk1GToQpEznxxmhdKZytSdlsfYE3UquoRjFWflCObD2bmQeSqhR8ZnMX0spd0DEJg3g/tQUQiNm8sJ8YA7FkcUpq4jWAcefprHyvCmrD2FGSxHCsbgmbI/FzotQu/HhLOXMPTJLH2laBkubX/JXMSc7rSmeKcD6BqBAUeVORkX7+b2BTck7OTwdSqMmNHjGgItZjK2YdoWryZF96PlEYNBHAZnoTGtjeg0xWIa6/5oZy8wIT9u/OzljW5HloSug8xZmH5XZVNGnTGbEtFFJUq0YMgtxwtVhbdHMQ07HPCi2M9OWJlPWIDltZtOiadwIRD8qGkWTEjSQmn9XnD2tR2MbEDl4uRhIAQgFxPty2zU8k4OO0r4TjeWkmNwjWFekkuzD4swUqjNgpgJ8I+GlByeRz7rMjNb1h5W5CURWv9QpdU1KEolaoHc8XrNlKBYCAxpuwGtVtJSNe9Bag6Pl7f23ZCsPwibB9s8Jk=";
      }];

      os_disk = [{
        name = "lumine-os-disk";
        caching = "ReadWrite";
        storage_account_type = "Standard_LRS";
      }];

      boot_diagnostics = [{
        storage_account_uri = config.resource.azurerm_storage_account.constellation "primary_blob_endpoint";
      }];
    };

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
      enable_accelerated_networking = false;

      ip_configuration = [
        {
          name = "ipv4cfg-1";
          subnet_id = config.resource.azurerm_subnet.celestia-subnet "id";
          public_ip_address_id = config.resource.azurerm_public_ip.lumine-ipv4-1 "id";
          primary = true;
          private_ip_address_allocation = "Dynamic";
          private_ip_address_version = "IPv4";
        }
        {
          name = "ipv6cfg-1";
          subnet_id = config.resource.azurerm_subnet.celestia-subnet "id";
          public_ip_address_id = config.resource.azurerm_public_ip.lumine-ipv6-1 "id";
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
