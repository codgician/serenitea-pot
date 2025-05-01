{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.postgresql;
  types = lib.types;
in
{
  options.codgician.services.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL";

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/postgresql";
      description = "The directory where PostgreSQL stores its data.";
    };

    zfsOptimizations = lib.mkEnableOption "Optimization for ZFS.";
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      inherit (cfg) enable;
      dataDir = "${cfg.dataDir}/${config.services.postgresql.package.psqlSchema}";
      settings = {
        full_page_writes = lib.mkIf cfg.zfsOptimizations false; # Not needed for ZFS
      };
    };
    environment.systemPackages = [ (import ./upgrade-pg-cluster.nix { inherit config lib pkgs; }) ];
  };
}
