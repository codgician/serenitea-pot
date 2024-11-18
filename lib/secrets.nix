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
  mkAgenixConfigs = owner: files: {
    age.secrets = builtins.listToAttrs (builtins.map
      (file: {
        name = getAgeSecretNameFromPath file;
        value = {
          inherit file owner;
          mode = "600";
        };
      })
      files);

    assertions = mkAgenixAssertions files;
  };
}
