{
  config,
  lib,
  ...
}:
let
  serviceName = "prometheus";
  cfg = config.codgician.services.${serviceName};
  types = lib.types;
in
{
  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption "prometheus";

    stateDirName = lib.mkOption {
      type = types.str;
      default = "prometheus2";
      description = "Directory below `/var/lib` to store Prometheus metrics data.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      stateDir = cfg.stateDirName;
    };
  };
}