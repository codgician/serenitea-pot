{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.redis;
  defaultRootDir = "/var/lib";

  # Canonical per-instance directory name, matching the upstream redis module:
  #   "" -> "redis", "foo" -> "redis-foo"
  redisName = name: "redis" + lib.optionalString (name != "") ("-" + name);

  # The path systemd's StateDirectory manages for an instance.
  stateDir = name: "/var/lib/${redisName name}";

  # Source directory under the custom root for an instance.
  rootedDir = name: "${cfg.rootDir}/${redisName name}";

  # All enabled redis server instances.
  enabledServers = lib.filterAttrs (_: srv: srv.enable) config.services.redis.servers;

  usingDefaultRoot = cfg.rootDir == defaultRootDir;
in
{
  options.codgician.services.redis.rootDir = lib.mkOption {
    type = lib.types.path;
    default = defaultRootDir;
    example = "/xpool/appdata";
    description = ''
      Root directory under which every enabled redis server instance keeps its
      state. Each instance lives at `''${rootDir}/redis-<name>`.

      When left at the default (`${defaultRootDir}`), each instance's state
      directory is registered with impermanence so it survives root wipes.

      When set to a custom location, impermanence registration is skipped (the
      location is assumed to live on persistent storage) and
      `''${rootDir}/redis-<name>` is bind-mounted onto the
      `/var/lib/redis-<name>` path that systemd's StateDirectory manages. This
      relocates both the data and the generated `redis.conf` while leaving the
      upstream redis module untouched.
    '';
  };

  config = lib.mkMerge [
    { services.redis.package = pkgs.valkey; }

    # Default root: persist each instance's state directory via impermanence.
    (lib.mkIf usingDefaultRoot {
      codgician.system.impermanence.extraItems = lib.mapAttrsToList (name: srv: {
        type = "directory";
        path = stateDir name;
        inherit (srv) user group;
      }) enabledServers;
    })

    # Custom root: relocate each instance onto ${rootDir} via a bind mount,
    # leaving the upstream module's hardcoded /var/lib/redis-<name> paths intact.
    (lib.mkIf (!usingDefaultRoot && enabledServers != { }) {
      # Create each bind source. tmpfiles runs after local-fs.target (and so
      # after zfs-mount.service, which is Before=local-fs.target), guaranteeing
      # /xpool-style pools are mounted first and the dirs land on persistent
      # storage. This mirrors the other services' custom-path handling.
      systemd.tmpfiles.rules = lib.mapAttrsToList (
        name: srv: "d ${rootedDir name} 0700 ${srv.user} ${srv.group} -"
      ) enabledServers;

      # Each redis-<name>.service pulls and orders after its bind mount.
      systemd.services = lib.mapAttrs' (
        name: _:
        lib.nameValuePair (redisName name) {
          unitConfig.RequiresMountsFor = [ (stateDir name) ];
        }
      ) enabledServers;

      # Bind each source onto the StateDirectory path via a dedicated mount unit.
      # systemd.mounts (not fileSystems) keeps this out of local-fs.target. The
      # source lives on a late-mounted pool, so DefaultDependencies is disabled to
      # avoid an ordering cycle and the shutdown ordering is re-added manually.
      # The mount is fail-closed against ZFS so it never binds a root-fs fallback;
      # redis-<name>.service orders after it via RequiresMountsFor, so its
      # StateDirectory chown/chmod runs against the bind-mounted target.
      systemd.mounts = lib.mapAttrsToList (name: _: {
        description = "Bind ${rootedDir name} to ${stateDir name}";
        what = rootedDir name;
        where = stateDir name;
        type = "none";
        options = "bind";
        requires = lib.optional config.boot.zfs.enabled "zfs-mount.service";
        after = lib.optional config.boot.zfs.enabled "zfs-mount.service";
        unitConfig.DefaultDependencies = false;
        conflicts = [ "umount.target" ];
        before = [ "umount.target" ];
      }) enabledServers;
    })
  ];
}
