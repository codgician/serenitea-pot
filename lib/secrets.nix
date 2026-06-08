{ lib, ... }:
rec {
  # Extract secret name from secret path
  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);

  # Convert secret name to secret path
  getAgeSecretPathFromName = name: lib.codgician.secretsDir + "/${name}.age";
}
