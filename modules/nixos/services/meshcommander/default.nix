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
    systemd.services.meshCommander = {
      enable = true;
      restartIfChanged = true;
      description = "Mesh Commander Server for Intel AMT Management";
      wantedBy = [ "default.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs}/bin/node --tls-min-v1.1 ${pkgs.nodePackages.meshcommander}/bin/meshcommander --port ${builtins.toString cfg.port}";
        ExecStop = "${pkgs.killall}/bin/killall meshcommander";
        Restart = "always";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    # User and group
    users = {
      users.meshCommander = lib.mkIf (cfg.user == "meshCommander") {
        group = cfg.group;
        isSystemUser = true;
      };
      groups.meshCommander = lib.mkIf (cfg.group == "meshCommander") { };
    };
  };
}
