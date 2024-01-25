{ config, lib, pkgs, ... }:
let
  dirs = builtins.readDir ./.;
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
  cfg = config.codgician.users;

  # Use list of sub-folder names as list of available users
  users = builtins.filter (name: dirs.${name} == "directory") (builtins.attrNames dirs);

  # Define module options for each user
  mkUserOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable user "${name}".'';
      extraSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = lib.mdDoc ''
          Extra agenix secret names owned by user "${name}" (excluding hashed password).
        '';
      };
    } // lib.optionalAttrs pkgs.stdenvNoCC.isLinux {
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = lib.mdDoc ''
          Auxiliary groups for user "${name}".
        '';
      };
    };
  };

  # Create assertions for each user
  mkUserAssertions = name: [
    # Each user must have hashed password file in secrets directory
    (
      let hashedPasswordFileName = "${name}HashedPassword.age"; in {
        assertion = !cfg.${name}.enable || builtins.pathExists ../../secrets/${hashedPasswordFileName};
        message = ''
          User '${name}' must have hashed password file (${hashedPasswordFileName}) in secrets directory.
        '';
      }
    )
  ];

  # Make configurations for each user
  mkUserConfig = name: lib.mkIf cfg.${name}.enable (lib.mkMerge [
    (import ./${name} { inherit config lib pkgs; })
    {
      assertions = mkUserAssertions name;
      users.users.${name} = lib.mkIf pkgs.stdenvNoCC.isLinux { extraGroups = cfg.${name}.extraGroups; };
      age.secrets =
        let
          secretsDir = builtins.toString ../../secrets;
          mkSecretConfig = fileName: {
            "${fileName}" = {
              file = "${secretsDir}/${fileName}.age";
              mode = "600";
              owner = name;
            };
          };
        in
        concatAttrs (builtins.map mkSecretConfig (cfg.${name}.extraSecrets ++ [ "${name}HashedPassword" ]));
    }
  ]);
in
builtins.trace "List of users: ${builtins.toString users}" {
  options.codgician.users = concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
