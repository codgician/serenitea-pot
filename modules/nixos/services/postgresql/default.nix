{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.postgresql;
  defaultDataDir = "/var/lib/postgresql";
in
{
  options.codgician.services.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL";
    # Pinned: another major version starts an empty cluster in its own data directory.
    package = lib.mkPackageOption pkgs "postgresql_17" { };

    enableTCPIP = lib.mkEnableOption "TCP/IP connections";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "Port for PostgreSQL to listen on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = defaultDataDir;
      description = "The directory where PostgreSQL stores its data.";
    };

    zfsOptimizations = lib.mkEnableOption "Optimization for ZFS.";
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = cfg.package.withJIT;
      inherit (cfg) enableTCPIP;
      dataDir = "${cfg.dataDir}/${config.services.postgresql.package.psqlSchema}";
      enableJIT = true;
      settings = {
        inherit (cfg) port;
        full_page_writes = lib.mkIf cfg.zfsOptimizations false; # Not needed for ZFS
      };
    };

    # Ensure data directory exists (for custom paths)
    systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir != defaultDataDir) [
      "d ${cfg.dataDir} 0750 postgres postgres -"
    ];

    # Persist postgresql data directory (only when using default location)
    codgician.system.impermanence.extraItems = lib.mkIf (cfg.dataDir == defaultDataDir) [
      {
        path = cfg.dataDir;
        type = "directory";
        user = "postgres";
        group = "postgres";
        mode = "0750";
      }
    ];

    environment.systemPackages = [ (import ./upgrade-pg-cluster.nix { inherit config lib pkgs; }) ];
  };
}
