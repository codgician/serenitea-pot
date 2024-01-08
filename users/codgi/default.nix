{ config, pkgs, lib, ... }:
let
  pubKeys = (import ../../secrets/secrets.nix).pubKeys;
  secretsDir = builtins.toString ../../secrets;
  ageSecrets = builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj));
in
{
  users.users.codgi = lib.mkMerge [
    {
      name = "codgi";
      description = "Shijia Zhang";
      home = if pkgs.stdenvNoCC.isLinux then "/home/codgi" else "/Users/codgi";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = pubKeys.users.codgi;
    }

    (lib.mkIf pkgs.stdenvNoCC.isLinux {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.age.secrets.codgiHashedPassword.path;
    })
  ];

  # Trust me
  nix.settings.trusted-users = [ "codgi" ];

  # User secret perms
  age.secrets = ageSecrets {
    "codgiPassword" = {
      mode = "600";
      owner = "codgi";
    };
    "codgiHashedPassword" = {
      mode = "600";
      owner = "codgi";
    };
  };
}
