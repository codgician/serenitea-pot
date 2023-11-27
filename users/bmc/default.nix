{ config, pkgs, lib, ... }:
let
  pubKeys = import ../../pubkeys.nix;
  secretsDir = builtins.toString ../../secrets;
  ageSecrets = builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj));
in
{
  users.users.bmc = {
    name = "bmc";
    description = "BMC";
    createHome = false;
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.bmcHashedPassword.path;
  };

  # Secret permissions
  age.secrets = ageSecrets {
    "bmcPassword" = {
      mode = "600";
      owner = "bmc";
    };
    "bmcHashedPassword" = {
      mode = "600";
      owner = "bmc";
    };
  };
}
