{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.users;
  systemCfg = config.codgician.system;
  types = lib.types;
  isLinux = pkgs.stdenvNoCC.isLinux;

  # Use list of sub-folder names as list of available users
  dirs = builtins.readDir ./.;
  users = builtins.filter (name: dirs.${name} == "directory") (builtins.attrNames dirs);

  # Define module options for each user
  mkUserOptions = name: {
    "${name}" =
      {
        enable = lib.mkEnableOption ''Enable user "${name}".'';

        createHome = lib.mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether or not to create home directory for user "${name}".
          '';
        };

        home = lib.mkOption {
          type = types.path;
          default = if isLinux then "/home/${name}" else "/Users/${name}";
          description = ''
            Path of home directory for user "${name}".
          '';
        };

        extraAgeFiles = lib.mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = ''
            Paths to `.age` secret files owned by user "${name}" excluding `hashedPasswordAgeFile`.
          '';
        };

        hashedPasswordAgeFile = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          visible = isLinux;
          description = ''
            Path to hashed password file encrypted managed by agenix.
          '';
        };

        passwordAgeFile = lib.mkOption {
          type = with types; nullOr path;
          default = null;
          description = ''
            Path to plain password file encrypted managed by agenix.
            This option does not set login password.
          '';
        };

      }
      // lib.optionalAttrs isLinux {
        extraGroups = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Auxiliary groups for user "${name}".
          '';
        };
      };
  };

  # Define assertions for each user
  mkUserAssertions =
    name:
    lib.mkIf cfg.${name}.enable [
      {
        assertion = !isLinux || cfg.${name}.hashedPasswordAgeFile != null;
        message = ''User "${name}" must have `hashedPasswordAgeFile` specified.'';
      }
    ];

  # Define configurations for each user
  mkUserConfig =
    name:
    lib.mkIf cfg.${name}.enable (
      lib.mkMerge [
        # Import user specific options
        (import ./${name} { inherit config lib pkgs; })

        # Impermanence: persist home directory if enabled
        {
          environment = lib.optionalAttrs (systemCfg ? impermanence) {
            persistence.${systemCfg.impermanence.path}.directories =
              lib.mkIf (systemCfg.impermanence.enable && cfg.${name}.createHome)
                [
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
        (
          let
            credFiles =
              cfg.${name}.extraAgeFiles
              ++ (builtins.filter (x: x != null) [
                cfg.${name}.passwordAgeFile
                cfg.${name}.hashedPasswordAgeFile
              ]);
          in
          lib.codgician.mkAgenixConfigs { owner = name; } credFiles
        )

        # Common options
        {
          assertions = mkUserAssertions name;
          users.users.${name} =
            {
              createHome = cfg.${name}.createHome;
              home = cfg.${name}.home;
            }
            // lib.optionalAttrs (cfg.${name} ? extraGroups) {
              extraGroups = cfg.${name}.extraGroups;
            }
            // lib.optionalAttrs isLinux {
              hashedPasswordFile =
                config.age.secrets."${lib.codgician.getAgeSecretNameFromPath
                  cfg.${name}.hashedPasswordAgeFile
                }".path;
            };
        }

        # Import home-manager modules (only when createHome is enabled)
        (lib.mkIf cfg.${name}.createHome {
          home-manager.users.${name} =
            { lib, ... }:
            let
              modules = import lib.codgician.hmModulesDir { inherit lib; };
              platform = if isLinux then "nixos" else "darwin";
            in
            {
              imports = lib.optionals (modules ? "${name}") [ (modules.${name}.${platform}) ];
            };
        })
      ]
    );
in
{
  options.codgician.users = lib.codgician.concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
