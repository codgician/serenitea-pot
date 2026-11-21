{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.secure-boot;
  pkiBundle = "/var/lib/sbctl";
in
{
  options.codgician.system.secure-boot.enable = lib.mkEnableOption ''
    Enable Secure Boot (only systemd-boot is supported).
  '';

  config = lib.mkMerge [
    {
      # Persisted regardless of enablement
      codgician.system.impermanence.extraItems = [
        {
          path = pkiBundle;
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
        inherit pkiBundle;
      };
    })
  ];
}
