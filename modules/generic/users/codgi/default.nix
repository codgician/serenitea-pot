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
      createHome = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = pubKeys.loginKeys.${name};
    }

    # Linux-specific configurations
    (lib.mkIf pkgs.stdenvNoCC.isLinux {
      isNormalUser = true;
      linger = true;
    })
  ];

  codgician.users.codgi.avatar =
    lib.mkDefault
      (pkgs.fetchurl {
        url = "https://media.githubusercontent.com/media/codgician/assets/refs/heads/main/images/user-tiles/zeitlind.png";
        sha256 = "sha256-r6hz3HA7xyDXpc855lUnB0UlJ1wwHona/nr1wgBtnFk=";
      }).outPath;

  # Trust me
  nix.settings.trusted-users = [ name ];

  # User-scope secrets
  codgician.secrets.files = {
    context7-api-key.owner = "codgi";
    github-auth-header.owner = "codgi";
    litellm-user-api-key.owner = "codgi";
  };
}
