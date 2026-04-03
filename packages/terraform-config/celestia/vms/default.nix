{ lib, ... }:
{
  imports = lib.codgician.getFolderPaths ./.;

  # Ensure encryption at host feature is enabled
  # See https://github.com/hashicorp/terraform-provider-azurerm/issues/17185
  resource.azurerm_resource_provider_feature_registration.encryption-at-host = {
    name = "EncryptionAtHost";
    provider_name = "Microsoft.Compute";
  };
}
