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
{
  options.codgician.services.plasma = {
    enable = lib.mkEnableOption "Plasma Desktop.";

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
        plasma-login-manager.enable = true;
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
    # Nixpkgs Electron wrappers use this to enable native Wayland and its IME protocol.
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

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

    # Persist Plasma Login Manager config
    codgician.system.impermanence.extraItems = [
      {
        path = "/var/lib/plasmalogin";
        type = "directory";
        user = "plasmalogin";
        group = "plasmalogin";
        mode = "0755";
      }
    ];

    # Install optional dependencies
    services.fwupd.enable = true;
    environment = {
      systemPackages = with pkgs; [
        pciutils
        usbutils
        clinfo
        mesa-demos
        vulkan-tools
        aha
        appmenu-glib-translator
        kdePackages.breeze-gtk
        kdePackages.kio-admin
        kdePackages.krdp
        kdePackages.krdc
        kdePackages.krfb
        kdePackages.kquickcharts
        kdePackages.krecorder
        kdePackages.kwallet-pam
        qt6.qtvirtualkeyboard
        wayland-utils
      ];
    };
  };
}
