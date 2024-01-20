{ config, lib, pkgs, ... }:
let
  users = [ "codgi" "bmc" ];
  concatAttrs = attrList: builtins.foldl' (x: y: x // y) { } attrList;
  cfg = config.codgician.users;
  mkUserOptions = name: {
    "${name}" = {
      enable = lib.mkEnableOption ''Enable user "${name}".'';
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = lib.mdDoc ''
          Auxiliary groups for user "${name}".
        '';
      };
      extraSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = lib.mdDoc ''
          Extra agenix secret names owned by user "${name}" (excluding hashed password).
        '';
      };
    };
  };
  mkUserConfig = name: lib.mkIf cfg."${name}".enable (lib.mkMerge [
    (import ./${name}.nix { inherit config lib pkgs; })
    {
      users.users."${name}".extraGroups = lib.mkIf pkgs.stdenvNoCC.isLinux cfg."${name}".extraGroups;
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
{
  options.codgician.users = concatAttrs (builtins.map mkUserOptions users);
  config = lib.mkMerge (builtins.map mkUserConfig users);
}
