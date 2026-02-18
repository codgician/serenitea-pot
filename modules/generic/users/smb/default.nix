{ pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
in
{
  users.users.smb = {
    inherit name;
    description = "samba user";
    isSystemUser = true;
    group = "nogroup";
    createHome = false;
    shell = "${pkgs.shadow}/bin/nologin";
  };
}
