{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.plasma;
  types = lib.types;
  usersWithAvatars = lib.filterAttrs (
    _: user: user.enable && user.avatar != null
  ) config.codgician.users;
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

    # Plasma Login Manager reads user avatars from AccountsService's icon directory.
    systemd.tmpfiles.rules = [
      "d /var/lib/AccountsService/icons 0755 root root -"
    ]
    ++ lib.mapAttrsToList (
      name: user: "L+ /var/lib/AccountsService/icons/${name} - - - - ${user.avatar}"
    ) usersWithAvatars;

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
        kdePackages.plasma-camera
        kdePackages.plasma-browser-integration
        kdePackages.plasma-keyboard
        qt6.qtvirtualkeyboard
        wayland-utils
      ];
    };
  };
}
