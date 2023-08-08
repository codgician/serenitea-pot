let
  pubKeys = import ../pubkeys.nix;
in
{
  "codgiPassword.age".publicKeys = builtins.concatLists [ pubKeys.users.codgi pubKeys.systems.pilot ];
}
