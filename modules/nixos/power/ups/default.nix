{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.codgician.power.ups;
in
{
  options.codgician.power.ups.devices = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.batteryLow = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Battery charge percentage at which the UPS will shut down.";
        };
      }
    );
    default = { };
    example.br1500g.batteryLow = 20;
    description = "Connected APC Back-UPS RS 1500G devices.";
  };

  config = lib.mkIf (cfg.devices != { }) {
    power.ups = {
      enable = true;
      mode = "standalone";
      openFirewall = true;
      users = {
        "admin" = {
          actions = [ "SET" ];
          instcmds = [ "ALL" ];
          upsmon = "primary";
          passwordFile = config.codgician.secrets.files.nut-password.path;
        };
        "upsmon".passwordFile = config.codgician.secrets.files.upsmon-password.path;
      };

      # Devices
      ups = builtins.mapAttrs (_: device: {
        driver = "usbhid-ups";
        description = "APC Back-UPS RS 1500G";
        port = "auto";
        directives = [
          "vendorid = 051D"
          "productid = 0002"
          "vendor = \"American Power Conversion\""
          "ondelay = 90"
          "offdelay = 60"
          "override.battery.charge.low = ${toString device.batteryLow}"
        ];
      }) cfg.devices;

      # Monitor
      upsmon = {
        monitor = builtins.mapAttrs (name: _: {
          user = "admin";
          powerValue = 1;
          type = "master";
          passwordFile = config.codgician.secrets.files.nut-password.path;
          system = name;
        }) cfg.devices;

        settings = {
          MINSUPPLIES = 1;
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
            address = "0.0.0.0";
            port = 3493;
          }
          {
            address = "::";
            port = 3493;
          }
        ];
      };

      schedulerRules = (import ./sched.nix { inherit pkgs lib; }).outPath;
    };
  };
}
