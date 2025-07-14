{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking) hostName;
  inherit (lib.codgician)
    secrets
    secretsDir
    secretNames
    getAgeSecretPathFromName
    ;
  cfg = config.codgician.system.agenix;

  # Make assertion rules for specified age file paths
  mkAgenixAssertions = builtins.map (file: {
    assertion = lib.pathExists file;
    message = "Credential '${file}' must exist.";
  });

  # Available secrets on current system
  pubkeyHosts = (import "${secretsDir}/pubkeys.nix").hosts;
  pubkeys = if (pubkeyHosts ? ${hostName}) then pubkeyHosts.${hostName} else [ ];
  isSecretAvailable =
    secretName:
    # Only check against the first public key in the list for simplicity
    pubkeys != [ ] && builtins.elem (builtins.head pubkeys) (secrets.${secretName}.publicKeys);
  availableSecretNames = builtins.filter isSecretAvailable secretNames;
in
{
  options.codgician.system.agenix = {
    secrets = lib.genAttrs secretNames (name: {
      owner = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Owner of secret ${name}.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Group of secret ${name}.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "600";
        description = "File mode of secret ${name}.";
      };
    });
  };

  config = {
    age.secrets = lib.genAttrs availableSecretNames (name: {
      inherit (cfg.secrets.${name}) owner group mode;
      file = getAgeSecretPathFromName name;
    });

    assertions = mkAgenixAssertions (builtins.map getAgeSecretPathFromName availableSecretNames);
    environment.systemPackages = with pkgs; [ agenix ];
  };
}
