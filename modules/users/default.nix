{ config, lib, pkgs, ... }:
let
  dirs = builtins.readDir ./.;
  secretsDir = builtins.toString ../../secrets;
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
  cfg = config.codgician.users;
  impermanenceCfg = config.codgician.system.impermanence;

  # Use list of sub-folder names as list of available users
  users = builtins.filter (name: dirs.${name} == "directory") (builtins.attrNames dirs);

  # Define module options for each user
  mkUserOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable user "${name}".'';
      createHome = lib.mkEnableOption ''Whether or not to create home directory for user "${name}".'';
      home = lib.mkOption {
        type = lib.types.path;
        default = if pkgs.stdenvNoCC.isLinux then "/home/${name}" else "/Users/${name}";
        description = lib.mdDoc ''
          Path of home directory for user "${name}".
        '';
      };
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
      let
        hashedPasswordFileName = "${name}HashedPassword.age";
        secretsFile = "${secretsDir}/secrets.nix";
      in
      {
        assertion = !cfg.${name}.enable ||
          (builtins.pathExists ../../secrets/${hashedPasswordFileName} && builtins.hasAttr hashedPasswordFileName (import secretsFile));
        message = ''
          User '${name}' must have hashed password file (${hashedPasswordFileName}) in secrets directory.
        '';
      }
    )
  ];

  # Make configurations for each user
  mkUserConfig = name: lib.mkIf cfg.${name}.enable (lib.mkMerge [
    (import ./${name} { inherit config lib pkgs; })

    (lib.mkIf impermanenceCfg.enable {
      environment.persistence.${impermanenceCfg.path}.directories = lib.mkIf pkgs.stdenvNoCC.isLinux [
        {
          directory = cfg.${name}.home;
          user = name;
          group = "users";
          mode = "u=rwx,g=rx,o=";
        }
      ];
    })

    {
      assertions = mkUserAssertions name;
      users.users.${name} = {
        createHome = cfg.${name}.createHome;
        home = cfg.${name}.home;
        extraGroups = lib.mkIf pkgs.stdenvNoCC.isLinux cfg.${name}.extraGroups;
      };

      age.secrets =
        let
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
{
  options.codgician.users = concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
