{ hmStateVersion, hmModules ? [ ] }:
{ config, pkgs, ... }:
let
  pubKeys = import ../../pubkeys.nix;
  secretsDir = builtins.toString ../../secrets;
  ageSecrets = builtins.mapAttrs (name: obj: ({ file = "${secretsDir}/${name}.age"; } // obj));
in
{
  # User profile settings
  users.users.codgi = {
    name = "codgi";
    description = "Shijia Zhang";
    home = "/home/codgi";
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.age.secrets.codgiHashedPassword.path;
    openssh.authorizedKeys.keys = pubKeys.users.codgi;
  };

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

  # Home manager profile
  home-manager.users.codgi = { config, ... }: rec {
    imports = [
      ../../users/codgi/git.nix
      ../../users/codgi/zsh.nix
    ] ++ hmModules;

    home.stateVersion = hmStateVersion;
    home.packages = with pkgs; [ httplz rnix-lsp iperf3 ];
  };
}
