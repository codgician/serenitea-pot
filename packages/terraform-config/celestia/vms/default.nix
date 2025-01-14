{ config, lib, ... }:
{
  imports = lib.codgician.getFolderPaths ./.;

  # Ensure encryption at host feature is enabled
  # See https://github.com/hashicorp/terraform-provider-azurerm/issues/17185
  resource.azapi_update_resource.encryptionAtHost = {
    type = "Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01";
    resource_id = "/subscriptions/${config.provider.azapi.subscription_id}/providers/Microsoft.Features/featureProviders/Microsoft.Compute/subscriptionFeatureRegistrations/encryptionathost";
    body = builtins.toJSON { properties = { }; };
  };
}
