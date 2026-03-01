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
      inherit (cfg) enable enableTCPIP;
      dataDir = "${cfg.dataDir}/${config.services.postgresql.package.psqlSchema}";
      enableJIT = true;
      settings = {
        inherit (cfg) port;
        full_page_writes = lib.mkIf cfg.zfsOptimizations false; # Not needed for ZFS
      };
    };

    # Persist postgresql data directory (only when using default location)
    codgician.system.impermanence.extraItems =
      lib.mkIf (config.codgician.system.impermanence.enable && cfg.dataDir == defaultDataDir)
        [
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
