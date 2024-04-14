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

    # Reverse proxy profile for nginx
    reverseProxy = {
      enable = lib.mkEnableOption "Enable reverse proxy for MeshCommander.";

      domains = lib.mkOption {
        type = types.listOf types.str;
        example = [ "example.com" "example.org" ];
        default = [ ];
        description = lib.mdDoc ''
          List of domains for the reverse proxy.
        '';
      };

      proxyPass = lib.mkOption {
        type = types.str;
        default = "http://127.0.0.1:${toString cfg.port}";
        defaultText = ''http://127.0.0.1:$\{toString config.codgician.services.meshcommander.port}'';
        description = lib.mdDoc ''
          Source URI for the reverse proxy.
        '';
      };

      lanOnly = lib.mkEnableOption "Only allow requests from LAN clients.";
    };
  };

  config = lib.mkMerge [
    # MeshCommander configurations
    (lib.mkIf cfg.enable {
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

      users = {
        users.meshcommander = lib.mkIf (cfg.user == "meshcommander") {
          group = cfg.group;
          isSystemUser = true;
        };
        groups.meshcommander = lib.mkIf (cfg.group == "meshcommander") { };
      };
    })

    # Reverse proxy profiles
    (lib.mkIf cfg.reverseProxy.enable {
      codgician.services.nginx = {
        enable = true;
        reverseProxies.meshcommander = {
          inherit (cfg.reverseProxy) enable domains;
          https = true;
          locations."/" = {
            inherit (cfg.reverseProxy) proxyPass lanOnly;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
      };
    })
  ];
}
