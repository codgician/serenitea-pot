{ config, lib, pkgs, ... }:
let
  dirs = builtins.readDir ./.;
  secretsDir = ../../secrets;
  secretsFile = secretsDir + "/secrets.nix";
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
  cfg = config.codgician.users;
  systemCfg = config.codgician.system;

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
    # Import user specific options
    (import ./${name} { inherit config lib pkgs; })

    # Impermanence: persist home directory if enabled
    {
      environment = lib.optionalAttrs (systemCfg?impermanence) {
        persistence.${systemCfg.impermanence.path}.directories =
          lib.mkIf (systemCfg.impermanence.enable && cfg.${name}.createHome) [
            {
              directory = cfg.${name}.home;
              user = name;
              group = "users";
              mode = "u=rwx,g=rx,o=";
            }
          ];
      };
    }

    # Agenix: manage secrets if enabled
    {
      age.secrets = lib.optionalAttrs (systemCfg?agenix && systemCfg.agenix.enable)
        (
          let
            mkSecretConfig = fileName: {
              "${fileName}" = {
                file = (secretsDir + "/${fileName}.age");
                mode = "600";
                owner = name;
              };
            };
          in
          concatAttrs (builtins.map mkSecretConfig (cfg.${name}.extraSecrets ++ [ "${name}HashedPassword" ]))
        );
    }

    # Common options
    {
      assertions = mkUserAssertions name;
      users.users.${name} = {
        createHome = cfg.${name}.createHome;
        home = cfg.${name}.home;
      } // lib.optionalAttrs (cfg.${name}?extraGroups) {
        extraGroups = cfg.${name}.extraGroups;
      } // lib.optionalAttrs pkgs.stdenvNoCC.isLinux {
        hashedPasswordFile = lib.mkIf (systemCfg?agenix && systemCfg.agenix.enable) config.age.secrets."${name}HashedPassword".path;
      };
    }
  ]);
in
{
  options.codgician.users = concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
