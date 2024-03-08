{ config, lib, pkgs, ... }:
let
  dirs = builtins.readDir ./.;
  secretsDir = ../../secrets;
  secretsFile = secretsDir + "/secrets.nix";
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
  cfg = config.codgician.users;
  agenixCfg = config.codgician.system.agenix;
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
          File names (excluding extension) additional secrets (agenix) owned by user "${name}" excluding "${name}HashedPassword".
          They should also be existing under `/secrets` directory.
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
  mkUserAssertions = name:
    let
      hashedPasswordFileName = "${name}HashedPassword.age";
      hashedPasswordFilePath = secretsDir + "/${hashedPasswordFileName}";
    in
    lib.mkIf cfg.${name}.enable [
      # Each user must have hashed password file in secrets directory
      {
        assertion = builtins.pathExists hashedPasswordFilePath;
        message = ''User '${name}' must have hashed password file: '${hashedPasswordFilePath}'.'';
      }
      {
        assertion = builtins.hasAttr hashedPasswordFileName (import secretsFile);
        message = '''${hashedPasswordFileName}' must be defined in '${secretsFile}'.'';
      }
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

    (lib.mkIf agenixCfg.enable {
      age.secrets =
        let
          mkSecretConfig = fileName: {
            "${fileName}" = {
              file = (secretsDir + "/${fileName}.age");
              mode = "600";
              owner = name;
            };
          };
        in
        concatAttrs (builtins.map mkSecretConfig (cfg.${name}.extraSecrets ++ [ "${name}HashedPassword" ]));
    })

    {
      assertions = mkUserAssertions name;
      users.users.${name} = {
        createHome = cfg.${name}.createHome;
        home = cfg.${name}.home;
        extraGroups = lib.mkIf pkgs.stdenvNoCC.isLinux cfg.${name}.extraGroups;
      };
    }
  ]);
in
{
  options.codgician.users = concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
