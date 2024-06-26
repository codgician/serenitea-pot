{ config, ... }: {
  imports = [
    ./image.nix
    ./network.nix
  ];

  resource = {
    # Ensure encryption at host feature is enabled
    # See https://github.com/hashicorp/terraform-provider-azurerm/issues/17185
    azapi_update_resource.encryptionAtHost = {
      type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01";
      resource_id = "/subscriptions/${config.provider.azapi.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Compute/subscriptionFeatureRegistrations/encryptionathost";
      body = builtins.toJSON { properties = { }; };
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
  };
}
