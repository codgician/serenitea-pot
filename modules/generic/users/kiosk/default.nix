{ pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
in
{
  users.users.kiosk = {
    inherit name;
    description = "Kiosk auto-login user.";
    createHome = true;
    isNormalUser = true;
    shell = pkgs.zsh;
  };
}
