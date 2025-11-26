{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.plasma;
  types = lib.types;
in
lib.optionalAttrs (lib.version >= "24.05") {
  options.codgician.services.plasma = {
    enable = lib.mkEnableOption "Plasma Desktop.";

    hidpi = lib.mkEnableOption "Hi-DPI support.";

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
          enableHidpi = cfg.hidpi;
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

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ kdePackages.xdg-desktop-portal-kde ];
      wlr.enable = true;
    };

    # Install optional dependencies
    services.fwupd.enable = true;
    environment = {
      systemPackages =
        with pkgs;
        (
          [
            pciutils
            usbutils
            clinfo
            mesa-demos
            vulkan-tools
            aha
            kdePackages.breeze-gtk
            kdePackages.kio-admin
            kdePackages.krdp
            kdePackages.kwallet-pam
            qt6.qtvirtualkeyboard
          ]
          ++ (lib.optionals cfg.wayland [ wayland-utils ])
        );
    };
  };
}
