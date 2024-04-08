{ config, lib, ... }:
let
  cfg = config.codgician.services.calibre-web;
  systemCfg = config.codgician.system;
  types = lib.types;
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Enable Calibre Web.";

    ip = lib.mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = lib.mdDoc ''
        IP for Calibre Web to listen on.
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 3002;
      description = lib.mdDoc ''
        Port for Calibre Web to listen on.
      '';
    };

    calibreLibrary = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = lib.mdDoc ''
        Path to Calibre library.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.calibre-web = {
      enable = true;
      listen = {
        port = cfg.port;
        ip = cfg.ip;
      };
      options = {
        enableKepubify = true;
        enableBookConversion = true;
        calibreLibrary = cfg.calibreLibrary;
      };
    };

    # Persist data
    environment = lib.optionalAttrs (systemCfg?impermanence) {
      persistence.${systemCfg.impermanence.path}.directories = [ "/var/lib/calibre-web" ];
    };
  };
}
