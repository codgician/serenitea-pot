{ config, lib, pkgs, ... }:
let
  name = "codgi";
  cfg = config.codgician.users.${name};
  pubKeys = import ../../secrets/pubKeys.nix;
in
{
  users.users.codgi = lib.mkMerge [
    # Generic configurations
    {
      inherit name;
      description = "Shijia Zhang";
      home = if pkgs.stdenvNoCC.isLinux then "/home/${name}" else "/Users/${name}";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = pubKeys.users.${name};
    }

    # Linux-specific configurations
    (lib.mkIf pkgs.stdenvNoCC.isLinux {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets."${name}HashedPassword".path;
    })
  ];

  # Trust me
  nix.settings.trusted-users = [ name ];
}
