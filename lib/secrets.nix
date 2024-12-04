{ lib, ... }: rec {
  # Extract secret name from secret path
  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);

  # Convert secret name to secret path
  getAgeSecretPathFromName = name: lib.codgician.secretsDir + "/${name}.age";

  # Make assertion rules for specified age file paths
  mkAgenixAssertions = builtins.map (file: {
    assertion = lib.pathExists file;
    message = "Credential '${file}' must exist.";
  });

  # Make agenix config for specified owner and age file paths
  mkAgenixConfigs = { owner ? "root", group ? "root", mode ? "600" }: files: {
    age.secrets = lib.pipe files [
      (builtins.map (file: {
        name = getAgeSecretNameFromPath file;
        value = { inherit file owner group mode; };
      }))
      builtins.listToAttrs
    ];
    assertions = mkAgenixAssertions files;
  };
}
