{ config, lib, ... }:
let
  cfg = config.codgician.services.calibre-web;
  systemCfg = config.codgician.system;
  types = lib.types;
in
{
  options.codgician.services.calibre-web = {
    enable = lib.mkEnableOption "Enable Calibre Web.";

    localhostOnly = lib.mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc "Only bind to localhost.";
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
        ip = if cfg.localhostOnly then "::1" else "::";
      };
      options = {
        enableKepubify = true;
        enableBookConversion = true;
        calibreLibrary = cfg.calibreLibrary;
      };
    };
  };
}
