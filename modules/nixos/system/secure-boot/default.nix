{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.secure-boot;
  impermanenceCfg = config.codgician.system.impermanence;
in
{
  options.codgician.system.secure-boot = {
    enable = lib.mkEnableOption "Enable Secure Boot.";
    pkiBundle = lib.mkOption {
      type = lib.types.path;
      default = "/etc/secureboot";
      description = ''
        Path to PKI bundle.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Persist /etc/secureboot if impermanence is on
    environment.persistence.${impermanenceCfg.path} = lib.mkIf impermanenceCfg.enable {
      directories = [ cfg.pkiBundle ];
    };

    # Include sbctl package
    environment.systemPackages = [ pkgs.sbctl ];

    # Lanzaboote will replace the systemd-boot module.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = cfg.pkiBundle;
    };
  };
}
