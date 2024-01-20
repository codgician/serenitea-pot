{ config, lib, pkgs, ... }:
let
  name = "codgi";
  cfg = config.codgician.users.${name};
  pubKeys = import ../../secrets/pubKeys.nix;
in
{
  users.users.codgi = {
    inherit name;
    description = "Shijia Zhang";
    home = if pkgs.stdenvNoCC.isLinux then "/home/${name}" else "/Users/${name}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = pubKeys.users.${name};
  };

  # Trust me
  nix.settings.trusted-users = [ name ];
} // lib.optionalAttrs pkgs.stdenvNoCC.isLinux {
  users.users.codgi = {
    isNormalUser = true;
    hashedPasswordFile = config.age.secrets."${name}HashedPassword".path;
  };
}
