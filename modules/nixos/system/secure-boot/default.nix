{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.secure-boot;
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.secure-boot = {
    enable = lib.mkEnableOption ''
      Enable Secure Boot (only systemd-boot is supported).
    '';

    pkiBundle = lib.mkOption {
      type = lib.types.path;
      default = "/etc/secureboot";
      description = ''
        Path to PKI bundle.
        This path will not be automatically persisted if set to non-default value with impermenance on.
      '';
    };
  };

  config = lib.mkMerge [
    # Persist /etc/secureboot if impermanence is on
    (lib.mkIf impermanenceCfg.enable  {
      environment.persistence.${impermanenceCfg.path} = {
        directories = [ "/etc/secureboot" ];
      };
    })

    (lib.mkIf cfg.enable {
      # Include sbctl package
      environment.systemPackages = [ pkgs.sbctl ];

      # Lanzaboote will replace the systemd-boot module.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = cfg.pkiBundle;
      };
    })
  ];
}
