{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.gnome;
  types = lib.types;
in
{
  options.codgician.services.gnome = {
    enable = lib.mkEnableOption "Gnome Desktop.";

    autoLoginUser = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Specify an auto-login user if you want to enable auto login.";
    };
  };

  config = lib.mkIf cfg.enable {
    # GNOME Keyring provides secret storage
    codgician.system.capabilities.hasSecretStorage = true;

    services = {
      xserver.enable = true;
      displayManager = {
        defaultSession = "gnome";

        gdm = {
          enable = true;
          wayland = true;
        };

        autoLogin = lib.mkIf (cfg.autoLoginUser != null) {
          enable = true;
          user = cfg.autoLoginUser;
        };
      };

      desktopManager.gnome = {
        enable = true;
        extraGSettingsOverrides = ''
          [org.gnome.mutter]
          experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
        '';
      };
    };

    # Enable dconf
    programs.dconf.enable = true;

    # Enable "Open in Terminal" context menu in Nautilus
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "kgx"; # GNOME Console
    };

    # Enable PAM auto-unlock for gnome-keyring (required for credential storage)
    security.pam.services.gdm-password.enableGnomeKeyring = true;

    # Configure keymap in X11
    services.xserver.xkb.layout = "us";

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gnome ];
      wlr.enable = true;
    };

    # Install optional dependencies
    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
      mesa-demos
      vulkan-tools
    ];
  };
}
