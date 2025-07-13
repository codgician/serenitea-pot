{ lib, ... }:
rec {
  # All agenix secrets
  secrets =
    with lib;
    mapAttrs' (secretName: secretCfg: nameValuePair (lib.removeSuffix ".age" secretName) secretCfg) (
      import "${lib.codgician.secretsDir}/secrets.nix"
    );
  secretNames = builtins.attrNames secrets;

  # Extract secret name from secret path
  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);

  # Convert secret name to secret path
  getAgeSecretPathFromName = name: lib.codgician.secretsDir + "/${name}.age";
}
