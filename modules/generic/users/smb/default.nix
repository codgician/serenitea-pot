{ ... }:
let
  name = builtins.baseNameOf ./.;
in
{
  users.users.smb = {
    inherit name;
    description = "samba user";
    isNormalUser = true;
    createHome = false;
  };
}
