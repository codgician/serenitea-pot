{ ... }:
let
  name = builtins.baseNameOf ./.;
in
{
  users.users.bmc = {
    inherit name;
    description = "bmc samba user";
    isNormalUser = true;
  };
}
