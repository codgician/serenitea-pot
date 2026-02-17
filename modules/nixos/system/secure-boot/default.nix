{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.secure-boot;
in
{
  options.codgician.system.secure-boot = {
    enable = lib.mkEnableOption ''
      Enable Secure Boot (only systemd-boot is supported).
    '';

    pkiBundle = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sbctl";
      description = ''
        Path to PKI bundle.
        This path will not be automatically persisted if set to non-default value with impermanence on.
      '';
    };
  };

  config = lib.mkMerge [
    {
      # Persist /etc/secureboot, do it regardless of enablement
      codgician.system.impermanence.extraItems = [
        {
          path = "/var/lib/sbctl";
          type = "directory";
        }
      ];

      # Include sbctl package
      environment.systemPackages = [ pkgs.sbctl ];
    }

    (lib.mkIf cfg.enable {
      # Lanzaboote will replace the systemd-boot module.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = cfg.pkiBundle;
      };
    })
  ];
}
