{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.plasma;
in
{
  options.codgician.services.plasma = {
    enable = lib.mkEnableOption "Enable Plasma Desktop.";
    wayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Wayland support for Plasma Desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      displayManager.sddm = {
        enable = true;
        enableHidpi = true;
        theme = "breeze";
      };
      desktopManager.plasma5 = {
        enable = true;
        useQtScaling = true;
      };
    };

    services.xserver.displayManager.defaultSession = lib.mkIf cfg.enable "plasmawayland";

    # Enable dconf
    programs.dconf.enable = true;

    # Auto unlock Kwallet
    security.pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };
  };
}
