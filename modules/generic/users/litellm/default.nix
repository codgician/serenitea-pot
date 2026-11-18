{ pkgs, ... }:
{
  # The service container maps this fixed uid/gid into its user namespace.
  users.users.litellm = {
    description = "LiteLLM service user.";
    createHome = false;
    uid = 2025;
    group = "litellm";
    shell = pkgs.zsh;
    isSystemUser = true;
  };

  users.groups.litellm.gid = 2025;
}
