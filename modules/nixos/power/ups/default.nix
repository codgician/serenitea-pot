{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.codgician.power.ups;
  types = lib.types;
  skuNames = lib.codgician.getNixFileNamesWithoutExt ./skus;
in
{
  options.codgician.power.ups = {
    devices = lib.mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            sku = lib.mkOption {
              type = types.enum skuNames;
              example = builtins.head skuNames;
              description = "SKU of the UPS device.";
            };

            description = lib.mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Description of the UPS.";
            };

            product = lib.mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Product name of the UPS (optional, used for matching device).";
            };

            serial = lib.mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Serial of the UPS (optional, used for matching device).";
            };

            port = lib.mkOption {
              type = with types; nullOr str;
              default = null;
              example = "/dev/ttyS0";
              description = "Port to which the UPS is connected.";
            };

            onDelay = lib.mkOption {
              type = types.int;
              default = 90;
              description = "Time to wait before switching on the UPS (seconds).";
            };

            offDelay = lib.mkOption {
              type = types.int;
              default = 60;
              description = "Time to wait before switching off the UPS (seconds).";
            };

            batteryLow = lib.mkOption {
              type = types.int;
              default = 10;
              description = ''
                Battery charge percentage at which the UPS will shut down.
                Note not all model support this configuration.
              '';
            };
          };
        });
      default = { };
      example = {
        br1500g = {
          sku = "br1500g";
          batteryLow = 20;
        };
      };
      description = "List of UPS device models that are connected.";
    };

    minSupplies = lib.mkOption {
      type = types.int;
      default = 1;
      description = ''
        Minimum number of power supplies that must be online for the UPS to
        consider the system to be powered.
      '';
    };

    sched = {
      shutdownTimer = lib.mkOption {
        type = types.int;
        default = 0;
        description = ''
          Time to wait before shutting down the system (seconds),
          regardless of UPS battery level. Set to 0 to disable.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.devices != { }) (
    lib.mkMerge [
      {
        power.ups = {
          enable = true;
          mode = "standalone";
          openFirewall = true;
          users = {
            "admin" = {
              actions = [ "SET" ];
              instcmds = [ "ALL" ];
              passwordFile = config.age.secrets.nutPassword.path;
            };
            "upsmon".passwordFile = config.age.secrets.upsmonPassword.path;
          };

          # Devices
          ups = builtins.mapAttrs (
            name: value: import (./skus + "/${value.sku}.nix") (value // { inherit lib; })
          ) cfg.devices;

          # Monitor
          upsmon = {
            monitor = builtins.mapAttrs (name: value: {
              user = "admin";
              powerValue = 1;
              type = "master";
              passwordFile = config.age.secrets.nutPassword.path;
              system = name;
            }) cfg.devices;

            settings = {
              MINSUPPLIES = cfg.minSupplies;
              NOTIFYFLAG = [
                [
                  "ONLINE"
                  "SYSLOG+WALL+EXEC"
                ]
                [
                  "ONBATT"
                  "SYSLOG+WALL+EXEC"
                ]
                [
                  "LOWBATT"
                  "SYSLOG+WALL+EXEC"
                ]
                [
                  "FSD"
                  "SYSLOG+WALL+EXEC"
                ]
                [
                  "COMMBAD"
                  "SYSLOG+EXEC"
                ]
                [
                  "COMMOK"
                  "SYSLOG+EXEC"
                ]
                [
                  "REPLBATT"
                  "SYSLOG+EXEC"
                ]
                [
                  "NOCOMM"
                  "SYSLOG+EXEC"
                ]
                [
                  "SHUTDOWN"
                  "SYSLOG+EXEC"
                ]
                [
                  "NOPARENT"
                  "SYSLOG+EXEC"
                ]
              ];
            };
          };

          upsd = {
            enable = true;
            listen = [
              {
                address = "::";
                port = 3493;
              }
            ];
          };

          schedulerRules = (import ./sched.nix { inherit config pkgs lib; }).outPath;
        };
      }

      # Agenix secrets
      (
        with lib.codgician;
        mkAgenixConfigs { } [
          (secretsDir + "/nutPassword.age")
          (secretsDir + "/upsmonPassword.age")
        ]
      )
    ]
  );
}
