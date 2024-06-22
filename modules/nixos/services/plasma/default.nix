{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.plasma;
  types = lib.types;
in
lib.optionalAttrs (lib.version >= "24.05") {
  options.codgician.services.plasma = {
    enable = lib.mkEnableOption "Enable Plasma Desktop.";

    wayland = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable Wayland support for Plasma Desktop.";
    };

    autoLoginUser = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Specify an auto-login user if you want to enable auto login.";
    };

    displayManager = lib.mkOption {
      type = types.enum [ "sddm" "lightdm" ];
      default = "sddm";
      example = "sddm";
      description = "Select display manager to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      xserver.enable = true;
      xserver.displayManager.lightdm = lib.mkIf (cfg.displayManager == "lightdm") {
        enable = true;
        # Workaround for autologin only working at first launch.
        # A logout or session crashing will show the login screen otherwise.
        extraSeatDefaults = ''
          session-cleanup-script=${pkgs.procps}/bin/pkill -P1 -fx ${pkgs.lightdm}/sbin/lightdm
        '';
      };

      displayManager = {
        defaultSession = "plasma";

        sddm = lib.mkIf (cfg.displayManager == "sddm") {
          enable = true;
          enableHidpi = true;
          theme = "breeze";
        };

        autoLogin = lib.mkIf (cfg.autoLoginUser != null) {
          enable = true;
          user = cfg.autoLoginUser;
        };
      };

      desktopManager.plasma6 = {
        enable = cfg.enable;
        enableQt5Integration = true;
      };
    };

    i18n.inputMethod.fcitx5.plasma6Support = true;

    # Enable dconf
    programs.dconf.enable = true;

    # Auto unlock Kwallet
    security.pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
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
      aha
      kdePackages.kio-admin
      qt6.qtvirtualkeyboard
    ];

    # Required for autorotate
    hardware.sensor.iio.enable = lib.mkDefault true;

    # todo: remove
    # hack to fix conflict
    programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
  };
}
