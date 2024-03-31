{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.jellyfin;
  systemCfg = config.codgician.system;
  types = lib.types;
in
rec {
  options.codgician.services.jellyfin = {
    enable = lib.mkEnableOption "Enable Jellyfin.";

    user = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = lib.mdDoc "User under which jellyfin runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "jellyfin";
      description = lib.mdDoc "Group under which jellyfin runs.";
    };

    dataDir = lib.mkOption {
      type = types.path;
      default = "/var/lib/jellyfin";
      description = lib.mdDoc "Data directory for jellyfin.";
    };
  };

  config =
    let
      virtualHost =
        if cfg.reverseProxy.domains == [ ]
        then null else builtins.head cfg.reverseProxy.domains;
    in
    lib.mkIf cfg.enable (lib.mkMerge [
      # Service
      {
        services.jellyfin = {
          enable = true;
          openFirewall = true;
          user = cfg.user;
          group = cfg.group;
        };

        # Persist data
        environment = lib.optionalAttrs (systemCfg?impermanence) {
          persistence.${systemCfg.impermanence.path}.directories =
            lib.mkIf (cfg.dataDir == options.codgician.services.jellyfin.dataDir.default) [ cfg.dataDir ];
        };
      }
    ]);
}
