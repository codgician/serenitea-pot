{
  lib,
  outputs,
  pkgs,
  ...
}:
let
  metadata = import ../../packages/terraform-config/celestia/cognitive/akasha/models.nix;
  terraformConfig = outputs.packages.${pkgs.stdenv.hostPlatform.system}.terraform-config.config;
  terraformDeployments = terraformConfig.resource.azurerm_cognitive_deployment or { };
  terraformModelNames = lib.sort builtins.lessThan (
    lib.mapAttrsToList (_: deployment: deployment.name) terraformDeployments
  );

  modelLib = import ../../modules/generic/models/lib.nix { inherit lib; };
  azureProvider = import ../../modules/generic/models/providers/azure {
    inherit lib modelLib;
  };
  registryModelNames = lib.sort builtins.lessThan (lib.attrNames azureProvider.provider.models);
  expectedModelNames = lib.attrNames metadata.deployments;
  # Deployments without `registry` (e.g. decision-1) are provisioned by
  # Terraform but deliberately not exposed in the model registry.
  expectedRegistryNames = lib.attrNames (
    lib.filterAttrs (_: deployment: deployment ? registry) metadata.deployments
  );

  onlyIn = left: right: builtins.filter (name: !(builtins.elem name right)) left;
  differences = {
    missingFromTerraform = onlyIn expectedModelNames terraformModelNames;
    unexpectedInTerraform = onlyIn terraformModelNames expectedModelNames;
    missingFromRegistry = onlyIn expectedRegistryNames registryModelNames;
    unexpectedInRegistry = onlyIn registryModelNames expectedRegistryNames;
  };
  consistent = lib.all (names: names == [ ]) (lib.attrValues differences);
in
{
  azureModelConsistency =
    assert lib.assertMsg consistent "Azure model metadata mismatch: ${builtins.toJSON differences}";
    pkgs.runCommand "azure-model-consistency" { } ''
      touch "$out"
    '';
}
