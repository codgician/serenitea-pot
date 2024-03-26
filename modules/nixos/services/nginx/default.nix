{ config, lib, ... }:
let
  cfg = config.codgician.services.nginx;
  types = lib.types;
in
{
  options.codgician.services.nginx = {
    enable = lib.mkEnableOption ''
      Enable nginx service.
    '';
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      statusPage = true;
    };

    services.prometheus.exporters = {
      nginx.enable = true;
      nginxlog.enable = true;
    };
  };
}
