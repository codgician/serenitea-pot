{ config, lib, pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
  cfg = config.codgician.users.${name};
in
{
  users.users.kiosk = {
    inherit name;
    description = "Kiosk auto-login user.";
    isNormalUser = true;
    shell = pkgs.zsh;
  };
}
