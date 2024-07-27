{ config, osConfig, lib, pkgs, ... }:
let
  cfg = config.codgician.codgi.plasma;
  types = lib.types;
in
{
  options.codgician.codgi.plasma = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.services.desktopManager.plasma6.enable
        || osConfig.services.xserver.desktopManager.plasma5.enable;
      description = ''Enable dotfiles for KDE plasma desktop.'';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;
      configFile = {
        kiorc.Confirmations.ConfirmEmptyTrash = true;
      };
    };
  };
}
