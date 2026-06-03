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
    services = {
      xserver.enable = true;
      displayManager = {
        defaultSession = "gnome";

        gdm = {
          enable = true;
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

      gnome = {
        core-apps.enable = true;
        core-developer-tools.enable = true;
        core-os-services.enable = true;
        core-shell.enable = true;
        gcr-ssh-agent.enable = true;
        glib-networking.enable = true;
        gnome-keyring.enable = true;
        gnome-remote-desktop.enable = true;
        gnome-settings-daemon.enable = true;
        localsearch.enable = true;
        sushi.enable = true;
        tinysparql.enable = true;
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
