{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.meshcommander;
  types = lib.types;
in
{
  options.codgician.services.meshcommander = {
    enable = lib.mkEnableOption "Enable MeshCommander.";

    port = lib.mkOption {
      type = types.port;
      default = 3001;
      description = lib.mdDoc "TCP port for MeshCommander to listen.";
    };

    localhostOnly = lib.mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc "Only bind to `127.0.0.1`.";
    };

    user = lib.mkOption {
      type = types.str;
      default = "meshcommander";
      description = lib.mdDoc "User under which MeshCommander runs.";
    };

    group = lib.mkOption {
      type = types.str;
      default = "meshcommander";
      description = lib.mdDoc "Group under which MeshCommander runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Systemd service for mesh commander
    systemd.services.meshcommander = {
      enable = true;
      restartIfChanged = true;
      description = "Mesh Commander Server for Intel AMT Management";
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs}/bin/node --tls-min-v1.1 ${pkgs.nodePackages.meshcommander}/bin/meshcommander --port ${builtins.toString cfg.port}"
          + (lib.optionalString (!cfg.localhostOnly) " --any");
        ExecStop = "${pkgs.killall}/bin/killall meshcommander";
        Restart = "always";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    # User and group
    users = {
      users.meshcommander = lib.mkIf (cfg.user == "meshcommander") {
        group = cfg.group;
        isSystemUser = true;
      };
      groups.meshcommander = lib.mkIf (cfg.group == "meshcommander") { };
    };
  };
}