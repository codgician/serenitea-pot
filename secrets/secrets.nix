let
  pubKeys = import ../pubKeys.nix;
in
{
  "codgiPassword.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi ];
}
