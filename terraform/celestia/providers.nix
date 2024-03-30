{
  terraform = {
    required_providers = {
      azurerm = {
        source = "hashicorp/azurerm";
        version = "~>3.0";
      };
    };

    backend.azurerm = {
      # This resource group is not managed terraform
      resource_group_name = "terraform";
      storage_account_name = "t7mstates";
      container_name = "celestia";
      key = "celestia.terraform.tfstate";
      # access_key provided with env variable "ARM_ACCESS_KEY"
    };
  };

  provider.azurerm = [
    {
      features = { };
      subscription_id = "d80e6deb-21e3-4aed-9455-5573a2086f66";
      tenant_id = "38a9ff63-6c70-437c-b513-04572e186549";
      client_id = "02ee1585-7d10-4f80-902d-910a0e5b7832";
      # client_secret provided with env variable "ARM_CLIENT_SECRET"
    }
  ];
}
