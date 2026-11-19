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

  # `enable` of the module of a service in `codgician.inventory.services`: on
  # by default on the host the inventory places the service on.
  mkPublishedEnableOption =
    config: name:
    lib.mkOption {
      type = lib.types.bool;
      default = (config.codgician.inventory.services.${name}.host or null) == config.networking.hostName;
      defaultText = lib.literalMD "true on the `host` of service `${name}` in `inventory.nix`";
      description = "Whether to run ${name} on this host.";
    };
}
