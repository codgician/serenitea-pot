{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenvNoCC) isDarwin isLinux;
in
{
  users.users.litellm = lib.mkMerge [
    {
      description = "LiteLLM service user.";
      createHome = false;
    }

    # The service container maps this fixed uid/gid into its user namespace.
    (lib.mkIf isLinux {
      uid = 2025;
      group = "litellm";
      shell = pkgs.zsh;
      isSystemUser = true;
    })

    # The nix-darwin LiteLLM daemon runs as this hidden user.
    (lib.mkIf isDarwin {
      isHidden = true;
      uid = lib.mkDefault 450;
    })
  ];

  users.groups.litellm = lib.mkIf isLinux { gid = 2025; };
}
