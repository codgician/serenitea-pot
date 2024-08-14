{ lib, pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
  pubKeys = import (lib.codgician.secretsDir + "/pubkeys.nix");
in
{
  users.users.codgi = lib.mkMerge [
    # Generic configurations
    {
      inherit name;
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
