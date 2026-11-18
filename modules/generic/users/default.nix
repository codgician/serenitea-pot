{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  system ? pkgs.stdenv.hostPlatform.system,
  ...
}:
let
  cfg = config.codgician.users;
  types = lib.types;
  isLinux = lib.hasSuffix "-linux" system;
  hmModules = import ../../../hm-modules { inherit lib; };

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

      avatar = lib.mkOption {
        type = with types; nullOr path;
        default = null;
        description = ''
          Path to an avatar image for user "${name}". Desktop-specific modules
          may consume this value to configure their user interface.
        '';
      };

      hashedPasswordSecret = lib.mkOption {
        type = with types; nullOr str;
        default = null;
        visible = isLinux;
        description = ''
          Name of the secret holding the hashed login password of user "${name}".
        '';
      };

      passwordSecret = lib.mkOption {
        type = with types; nullOr str;
        default = null;
        description = ''
          Name of the secret holding the plaintext password of user "${name}",
          read at runtime (e.g. by smbpasswd). It does not set the login password.
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
        # Users without a hashed-password secret are locked by default; a
        # host may still give them a password, which overrides the lock.
        assertion =
          !isLinux
          || config.users.users.${name}.isSystemUser
          || cfg.${name}.hashedPasswordSecret != null
          || config.users.users.${name}.hashedPassword != "!";
        message = ''User "${name}" would be locked: set `hashedPasswordSecret` or a password.'';
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
          codgician.secrets.files =
            lib.optionalAttrs (cfg.${name}.passwordSecret != null) {
              ${cfg.${name}.passwordSecret}.owner = name;
            }
            # users.users.<name>.hashedPasswordFile is read before /run/secrets
            # exists, so the secret decrypts early and stays root-owned.
            // lib.optionalAttrs (cfg.${name}.hashedPasswordSecret != null) {
              ${cfg.${name}.hashedPasswordSecret}.neededForUsers = true;
            };

          codgician.system = lib.optionalAttrs (config.codgician.system ? impermanence) {
            # Impermanence: persist home directory if enabled
            impermanence.extraItems = [
              {
                type = "directory";
                path = cfg.${name}.home;
                user = name;
                group = config.users.users.${name}.group;
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
          // lib.optionalAttrs isLinux (
            if cfg.${name}.hashedPasswordSecret != null then
              {
                hashedPasswordFile = config.codgician.secrets.files.${cfg.${name}.hashedPasswordSecret}.path;
              }
            else
              { hashedPassword = lib.mkDefault "!"; }
          );
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
  options.codgician.users = lib.mergeAttrsList (builtins.map mkUserOptions users);
  config = lib.mkMerge (
    (builtins.map mkUserConfig users)
    ++ [ { home-manager.extraSpecialArgs = { inherit inputs outputs; }; } ]
  );
}
