{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  cfg = config.codgician.users;
  types = lib.types;
  inherit (pkgs.stdenvNoCC) isLinux;
  hmModules = import lib.codgician.hmModulesDir { inherit lib; };
  invalidHashedPasswordFile = pkgs.writeText "hashed-password" "!";

  # Use list of sub-folder names as list of available users
  dirs = builtins.readDir ./.;
  users = builtins.filter (name: dirs.${name} == "directory") (builtins.attrNames dirs);

  # Define module options for each user
  mkUserOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable user "${name}".'';

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
        assertion =
          !isLinux || config.users.users.${name}.isSystemUser || cfg.${name}.hashedPasswordAgeFile != null;
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

        {
          codgician.system = {
            # Agenix secrets
            agenix.secrets =
              let
                credFiles =
                  cfg.${name}.extraAgeFiles
                  ++ (builtins.filter (x: x != null) [
                    cfg.${name}.passwordAgeFile
                    cfg.${name}.hashedPasswordAgeFile
                  ]);
                credNames = builtins.map (x: lib.codgician.getAgeSecretNameFromPath x) credFiles;
              in
              lib.genAttrs credNames (_: {
                owner = name;
              });
          }
          // lib.optionalAttrs (config.codgician.system ? impermanence) {
            # Impermanence: persist home directory if enabled
            impermanence.extraItems = [
              {
                type = "directory";
                path = cfg.${name}.home;
                user = name;
                group = "users";
                mode = "700";
              }
            ];
          };
        }

        # Common options
        {
          assertions = mkUserAssertions name;
          users.users.${name} = {
            inherit (cfg.${name}) home;
          }
          // lib.optionalAttrs (cfg.${name} ? extraGroups) {
            inherit (cfg.${name}) extraGroups;
          }
          // lib.optionalAttrs isLinux {
            hashedPasswordFile =
              if cfg.${name}.hashedPasswordAgeFile == null then
                invalidHashedPasswordFile.outPath
              else
                config.age.secrets."${lib.codgician.getAgeSecretNameFromPath
                  cfg.${name}.hashedPasswordAgeFile
                }".path;
          };
        }

        # Mark as known users in nix-darwin
        { users = lib.optionalAttrs (users ? knownUsers) { knownUsers = [ name ]; }; }

        # Import home-manager modules only when there are HM modules for this user
        (lib.mkIf (hmModules ? "${name}") {
          home-manager.users.${name} =
            { ... }:
            {
              imports = [ hmModules.${name}.${if isLinux then "nixos" else "darwin"} ];
            };
        })
      ]
    );
in
{
  options.codgician.users = lib.codgician.concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (
    (builtins.map mkUserConfig users)
    ++ [ { home-manager.extraSpecialArgs = { inherit inputs outputs; }; } ]
  );
}
