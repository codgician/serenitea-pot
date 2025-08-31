{ lib, pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
  inherit (pkgs.stdenvNoCC) isDarwin;
in
{
  users.users.codgi = lib.mkMerge [
    # Generic configurations
    {
      inherit name;
      uid = if isDarwin then 501 else 1000;
      description = "Shijia Zhang";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = pubKeys.users.${name};
    }

    # Linux-specific configurations
    (lib.mkIf pkgs.stdenvNoCC.isLinux {
      isNormalUser = true;
    })
  ];

  # Trust me
  nix.settings.trusted-users = [ name ];
}
