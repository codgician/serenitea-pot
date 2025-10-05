{ config, lib, ... }:
let
  serviceName = "sing-box";
  cfg = config.codgician.services.${serviceName};
  user = serviceName;
  group = serviceName;
in
{
  imports = builtins.concatMap (lib.codgician.getNixFilePaths) [
    ./clients
    ./servers
  ];

  options.codgician.services.${serviceName} = {
    enable = lib.mkEnableOption serviceName;

    users = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        List of user names that can access sing-box server(s).
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # General settings
      {
        services.sing-box = {
          enable = true;
          settings = {
            log = {
              disabled = false;
              level = "warn";
              timestamp = true;
            };

            dns.servers = [
              {
                type = "local";
                tag = "local";
              }
            ];

            outbounds = [
              {
                tag = "outbound-direct";
                type = "direct";
                domain_resolver.server = "local";
              }
            ];
          };
        };

        # Configure user and group for running sing-box
        systemd.services.sing-box.serviceConfig = {
          User = user;
          Group = group;
        };

        users = {
          users.${user} = {
            inherit group;
            isSystemUser = true;
          };
          groups.${group} = { };
        };

        # Agenix secrets
        codgician.system.agenix.secrets =
          lib.genAttrs (builtins.map (x: "sing-${x}-proxy-password") cfg.users)
            (name: {
              owner = user;
              inherit group;
              mode = "0600";
            });
      }
    ]
  );
}
