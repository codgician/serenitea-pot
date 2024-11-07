{ config, lib, ... }:
let
  cfg = config.codgician.power.ups;
  types = lib.types;
  deviceNames = lib.codgician.getNixFileNamesWithoutExt ./devices;
in
{
  imports = lib.codgician.getNixFilePaths ./devices;

  options.codgician.power.ups = {
    devices = lib.mkOption {
      type = with types; listOf (enum deviceNames);
      default = [ ];
      description = "List of UPS device models that are connected.";
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

  config = lib.mkIf ((builtins.length cfg.devices) > 0) (lib.mkMerge [
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

        upsd = {
          enable = true;
          listen = [
            { address = "::"; port = 3493; }
          ];
        };
      };
    }

    # Agenix secrets
    (lib.codgician.mkAgenixConfigs "root" [
      (lib.codgician.secretsDir + "/nutPassword.age")
      (lib.codgician.secretsDir + "/upsmonPassword.age")
    ])
  ]);
}
