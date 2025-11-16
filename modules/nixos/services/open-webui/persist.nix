{
  lib,
  cfg,
  options,
  serviceName,
  ...
}:
{
  # Persist data when dataDir is default value
  codgician.system.impermanence.extraItems =
    lib.mkIf (cfg.stateDir == options.codgician.services.open-webui.stateDir.default)
      [
        {
          type = "directory";
          path = "/var/lib/open-webui";
          user = serviceName;
          group = serviceName;
        }
      ];
}
