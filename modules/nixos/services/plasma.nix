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
    autoLoginUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Specify an auto-login user if you want to enable auto login.";
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

    # Auto-login
    services.xserver.displayManager.autoLogin = lib.mkIf (builtins.stringLength cfg.autoLoginUser > 0) {
      enable = true;
      user = cfg.autoLoginUser;
    };

    # Configure keymap in X11
    services.xserver = {
      layout = "us";
      xkbVariant = "";
    };

    # Install optional dependencies
    services.fwupd.enable = true;
    environment.systemPackages = with pkgs; [
      breeze-gtk
      pciutils
      usbutils
      clinfo
      glxinfo
      vulkan-tools
      wayland-utils
      libsForQt5.kio-admin
    ];
  };
}
