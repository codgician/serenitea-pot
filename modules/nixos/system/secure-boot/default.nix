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

  config = lib.mkIf cfg.enable {
    # Include sbctl package
    environment.systemPackages = [ pkgs.sbctl ];

    # Lanzaboote will replace the systemd-boot module.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = cfg.pkiBundle;
    };

    # Persist /etc/secureboot
    codgician.system.impermanence.extraItems = [
      {
        path = "/var/lib/sbctl";
        type = "directory";
      }
    ];
  };
}
