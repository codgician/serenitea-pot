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
          Path identifying the hashed-password secret (its basename without the
          .age suffix selects the managed secret). Decrypted early as a
          neededForUsers secret so it backs users.users.<name>.hashedPasswordFile.
        '';
      };

      passwordAgeFile = lib.mkOption {
        type = with types; nullOr path;
        default = null;
        description = ''
          Path identifying the plaintext-password secret (basename without .age
          selects the managed secret). Consumed at runtime (e.g. by smbpasswd);
          this option does not set the login password.
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
          # Secrets
          codgician.secrets.files =
            let
              nameOf = lib.codgician.getAgeSecretNameFromPath;
              # Only declare secrets THIS host can decrypt; a host that is not a
              # recipient must not try to materialize the file (activation fails).
              thisHostKeys = lib.codgician.registry.pubkeys.hosts.${config.networking.hostName} or [ ];
              canDecrypt =
                n:
                lib.any (k: builtins.elem k thisHostKeys) (lib.codgician.registry.secrets.${n}.publicKeys or [ ]);

              # passwordAgeFile (plaintext, read at runtime e.g. by smbpasswd) and
              # extraAgeFiles stay user-owned in /run/secrets.
              runtimeNames = builtins.map nameOf (
                cfg.${name}.extraAgeFiles
                ++ lib.optional (cfg.${name}.passwordAgeFile != null) cfg.${name}.passwordAgeFile
              );
              # hashedPasswordAgeFile feeds users.users.<name>.hashedPasswordFile,
              # read before /run/secrets exists, so it must decrypt early
              # (neededForUsers) and therefore be root-owned.
              hashedNames = lib.optional (cfg.${name}.hashedPasswordAgeFile != null) (
                nameOf cfg.${name}.hashedPasswordAgeFile
              );

              runtimeDecls = lib.genAttrs (builtins.filter canDecrypt runtimeNames) (_: {
                owner = name;
              });
              hashedDecls = lib.genAttrs (builtins.filter canDecrypt hashedNames) (_: {
                neededForUsers = true;
              });
            in
            # hashed wins on collision (root + neededForUsers).
            runtimeDecls // hashedDecls;

          codgician.system = lib.optionalAttrs (config.codgician.system ? impermanence) {
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
                config.codgician.secrets.files."${lib.codgician.getAgeSecretNameFromPath
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
