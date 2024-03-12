{ config, lib, pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
  cfg = config.codgician.users.${name};
in
{
  users.users.bmc = {
    inherit name;
    description = "bmc samba user";
    isNormalUser = true;
  };
}
