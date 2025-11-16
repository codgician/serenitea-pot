{
  lib,
  pkgs,
  cfg,
  pgCfg,
  pgDbName,
  serviceName,
  ...
}:

lib.mkMerge [
  {
    # Set up Redis
    services.redis.servers.${serviceName} = {
      enable = true;
      unixSocketPerm = 660;
    };
  }

  (lib.mkIf (cfg.enable && cfg.database == "postgresql") {
    # PostgreSQL
    codgician.services.postgresql.enable = true;
    services.postgresql = {
      extensions =
        ps: with ps; [
          pgvector
          pgvectorscale
        ];
      ensureDatabases = [ pgDbName ];
      ensureUsers = [
        {
          name = serviceName;
          ensureDBOwnership = true;
        }
      ];
    };

    # PostgreSQL: enable pgvector
    systemd.services.postgresql.serviceConfig.ExecStartPost =
      let
        sqlFile = pkgs.writeText "open-webui-pgvector-init.sql" ''
          CREATE EXTENSION IF NOT EXISTS vector;
        '';
      in
      ''
        ${lib.getExe' pgCfg.package "psql"} -d "${pgDbName}" -f "${sqlFile}"  
      '';
  })

]
