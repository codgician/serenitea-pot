{ config, lib, pkgs, ... }:
let
  name = "bmc";
  cfg = config.codgician.users.${name};
  secretsDir = builtins.toString ../../secrets;
in
{
  users.users.bmc = {
    inherit name;
    description = "bmc samba user";
    createHome = false;
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets.bmcHashedPassword.path;
    extraGroups = cfg.extraGroups;
  };
}
