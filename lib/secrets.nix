{ lib, codgician, ... }: rec {
  secretsDir = ../secrets;

  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);

  mkAgenixAssertions = builtins.map (credPath: {
    assertion = lib.pathExists credPath;
    message = "Credential '${credPath}' must exist.";
  });
}
