{ config, lib, ... }:
let
  cfg = config.codgician.power.ups;
  types = lib.types;
  deviceNames = lib.codgician.getNixFileNamesWithoutExt ./devices;
in
{
  imports = lib.codgician.getNixFilePaths ./devices;

  options.codgician.power.ups.devices = lib.mkOption {
    type = with types; listOf (enum deviceNames);
    default = [ ];
    description = "List of UPS device models that are connected.";
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
