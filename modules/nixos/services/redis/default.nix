{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Get all enabled redis server instances
  enabledServers = lib.filterAttrs (_: srv: srv.enable) config.services.redis.servers;
in
{
  config = {
    services.redis.package = pkgs.valkey;

    # Persist data directories for all enabled redis instances
    codgician.system.impermanence.extraItems = lib.mapAttrsToList (name: srv: {
      type = "directory";
      path = "/var/lib/redis-${name}";
      user = srv.user;
      group = srv.group;
    }) enabledServers;
  };
}
