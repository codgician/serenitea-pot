{ lib, pkgs, ... }:
let
  name = builtins.baseNameOf ./.;
  inherit (pkgs.stdenvNoCC) isDarwin isLinux;
in
{
  users.users.litellm = lib.mkMerge [
    # Common attributes
    {
      inherit name;
      description = "LiteLLM service user.";
      createHome = false;
    }

    # Linux-specific attributes
    (lib.mkIf isLinux {
      # For NixOS service & container: fixed uid/gid and shell
      uid = 2025;
      group = name;
      shell = pkgs.zsh;
      isSystemUser = true;
    })

    # Darwin-specific attributes
    (lib.mkIf isDarwin {
      isHidden = true;
      uid = lib.mkDefault 450;
    })
  ];

  # Ensure group exists on Linux
  users.groups.litellm = lib.mkIf isLinux {
    gid = 2025;
  };
}
