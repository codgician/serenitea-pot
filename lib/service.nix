{ lib, ... }:
{
  # Make user and group on Linux for service
  mkServiceUserGroupLinux =
    name:
    {
      uid ? null,
      gid ? null,
    }:
    {
      users.users.${name} = {
        uid = lib.mkIf (uid != null) uid;
        group = name;
        isSystemUser = true;
      };
      users.groups.${name} = {
        gid = lib.mkIf (gid != null) gid;
      };
    };
}
