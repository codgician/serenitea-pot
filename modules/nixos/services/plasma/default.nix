{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.plasma;
in
lib.optionalAttrs (lib.version >= "24.05") {
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
    services = {
      xserver = {
        enable = true;
        displayManager.sddm = {
          enable = true;
          enableHidpi = true;
          theme = "breeze";
        };
      };
      desktopManager.plasma6 = {
        enable = true;
        enableQt5Integration = true;
      };
    };

    i18n.inputMethod.fcitx5.plasma6Support = true;

    services.xserver.displayManager.defaultSession = lib.mkIf cfg.enable "plasma";

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
    services.xserver.xkb.layout = "us";

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
      kdePackages.kio-admin
    ];
  };
}
