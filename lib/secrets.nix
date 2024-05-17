{ lib, ... }: rec {
  secretsDir = ../secrets;

  getAgeSecretNameFromPath = path: lib.removeSuffix ".age" (builtins.baseNameOf path);

  mkAgenixAssertions = builtins.map (file: {
    assertion = lib.pathExists file;
    message = "Credential '${file}' must exist.";
  });

  mkAgenixConfigs = owner: files: {
    age.secrets = lib.codgician.concatAttrs (builtins.map
      (file: {
        "${getAgeSecretNameFromPath file}" = {
          inherit file owner;
          mode = "600";
        };
      })
      files);

    assertions = mkAgenixAssertions files;
  };
}
