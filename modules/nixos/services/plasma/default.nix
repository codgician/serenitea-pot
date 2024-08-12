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
  };

  config = lib.mkIf cfg.enable {
    services = {
      xserver.enable = true;
      displayManager = {
        defaultSession = "plasma";

        sddm = {
          enable = true;
          enableHidpi = true;
          theme = "breeze";
          wayland = {
            enable = cfg.wayland;
            compositor = "kwin";
          };
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
    security.pam.services = {
      login.kwallet.enable = true;
      kde = {
        allowNullPassword = true;
        kwallet.enable = true;
      };
      kde-fingerprint = lib.mkIf config.services.fprintd.enable { fprintAuth = true; };
      kde-smartcard = lib.mkIf config.security.pam.p11.enable { p11Auth = true; };
    };

    # Configure keymap in X11
    services.xserver.xkb.layout = "us";

    # Install optional dependencies
    services.fwupd.enable = true;
    environment.systemPackages = with pkgs; ([
      breeze-gtk
      pciutils
      usbutils
      clinfo
      glxinfo
      vulkan-tools
      aha
      kdePackages.kio-admin
      qt6.qtvirtualkeyboard
    ] ++ (lib.optionals cfg.wayland [ wayland-utils ]));

    # Required for autorotate
    hardware.sensor.iio.enable = lib.mkDefault true;

    # todo: remove
    # hack to fix conflict
    programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
  };
}
