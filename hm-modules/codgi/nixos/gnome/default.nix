{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.gnome;
  types = lib.types;
  useIbus =
    (osConfig.i18n.inputMethod.enable or false) && (osConfig.i18n.inputMethod.type or null) == "ibus";
in
{
  options.codgician.codgi.gnome = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.codgician.services.gnome.enable or false;
      description = "Enable dotfiles for GNOME desktop.";
    };

    favoriteApps = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "org.gnome.Console.desktop"
      ]
      ++ (lib.optional (config.codgician.codgi.vscode.enable or false) "code.desktop");
      description = "List of .desktop file names to pin in the GNOME dock.";
    };

    wallpaper = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Wallpaper shared by the GNOME desktop and lock screen.";
    };
  };

  config = lib.mkIf cfg.enable {
    # GNOME Shell extensions
    programs.gnome-shell = {
      enable = true;
      extensions = [
        { package = pkgs.gnomeExtensions.appindicator; }
        { package = pkgs.gnomeExtensions.blur-my-shell; }
        { package = pkgs.gnomeExtensions.dash-to-dock; }
        { package = pkgs.gnomeExtensions.gsconnect; }
        { package = pkgs.gnomeExtensions.touchup; }
      ];
    };

    # dconf settings for GNOME-specific behavior only
    # Theme/cursor/icon settings are handled by gtk module below
    dconf.settings = {
      # Desktop interface - behavior settings only
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        clock-format = "12h";
        clock-show-weekday = true;
        enable-hot-corners = false;
        font-antialiasing = "rgba";
        font-hinting = "slight";
        # Accessibility: locate pointer on Ctrl press (like KDE shake cursor)
        locate-pointer = true;
      };

      "org/gnome/desktop/background" = lib.mkIf (cfg.wallpaper != null) {
        picture-uri = "file://${cfg.wallpaper}";
        picture-uri-dark = "file://${cfg.wallpaper}";
        picture-options = "zoom";
      };

      "org/gnome/desktop/screensaver" = lib.mkIf (cfg.wallpaper != null) {
        picture-uri = "file://${cfg.wallpaper}";
        picture-options = "zoom";
      };

      # Native IBus input sources (US + Rime-Ice) when IBus is active
      "org/gnome/desktop/input-sources" = lib.mkIf useIbus {
        sources = [
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "us"
          ])
          (lib.hm.gvariant.mkTuple [
            "ibus"
            "rime"
          ])
        ];
        xkb-options = [ ];
      };

      # Match Ctrl+Space input switching while keeping GNOME's Super+Space default
      "org/gnome/desktop/wm/keybindings" = lib.mkIf useIbus {
        switch-input-source = [
          "<Control>space"
          "<Super>space"
        ];
        switch-input-source-backward = [
          "<Shift><Control>space"
          "<Shift><Super>space"
        ];
      };

      # Window manager preferences
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };

      "org/gnome/mutter" = {
        center-new-windows = true;
        edge-tiling = true;
      };

      # Favorite apps in dock (equivalent to plasma taskbar pinned apps)
      "org/gnome/shell" = {
        favorite-apps = cfg.favoriteApps;
      };

      # Dash-to-dock settings (macOS-like behavior)
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        extend-height = false;
        disable-overview-on-startup = true;

        # Multi-monitor: show on all monitors, prefer primary
        multi-monitor = true;
        preferred-monitor = lib.hm.gvariant.mkInt32 (-1);

        # macOS-like auto-hide behavior
        dock-fixed = false;
        autohide = true;
        intellihide = true;
        intellihide-mode = "ALL_WINDOWS";
        autohide-in-fullscreen = true;
        show-dock-urgent-notify = false;
        animation-time = 0.2;
        hide-delay = 0.2;
        show-delay = 0.0;
        pressure-threshold = 50.0;
        require-pressure-to-show = true;

        # Appearance
        dash-max-icon-size = lib.hm.gvariant.mkInt32 48;
        custom-theme-shrink = true;
        running-indicator-style = "DOTS";

        # Use FIXED transparency with 0 opacity so blur-my-shell can handle the blur
        transparency-mode = "FIXED";
        background-opacity = 0.0;

        # Show trash and mounted volumes like macOS
        show-trash = true;
        show-mounts = true;

        # Behavior
        click-action = "minimize-or-previews";
        scroll-action = "cycle-windows";
        apply-custom-theme = false;
      };

      # TouchUp: iPadOS/Android-style gestures, OSK enhancements, and touch navigation
      "org/gnome/shell/extensions/touchup" = {
        navigation-bar-enabled = true;
        navigation-bar-mode = "gestures";
        # Only activate the bottom capture bar in touch mode so desktop mouse
        # clicks/drags along the bottom 22px (status bars, dock) aren't intercepted.
        navigation-bar-ignore-touch-mode = false;
        navigation-bar-gestures-reserve-space = false;
        navigation-bar-gestures-invisible-mode = "never";
        navigation-bar-primary-monitor-follows-navbar = false;

        desktop-background-gestures-enabled = true;
        overview-background-gestures-enabled = true;
        window-preview-gestures-enabled = true;
        notification-gestures-enabled = true;

        osk-key-popups-enabled = true;
        osk-gestures-swipe-to-close-enabled = true;
        osk-gestures-extend-keys-enabled = true;
        osk-quick-paste-action-enabled = true;
        osk-space-bar-ime-switching-enabled = true;

        screen-rotate-utils-floating-screen-rotate-button-enabled = true;
        # Locks the screen only (never suspends).
        double-tap-to-sleep-enabled = true;
      };

      # Blur-my-shell settings (replicates KDE blur effect)
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.85;
        sigma = lib.hm.gvariant.mkInt32 15; # Match KDE blur strength
        noise-amount = 0.05; # Match KDE noise strength (5/100)
      };

      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = true;
        static-blur = true;
        override-background = true;
        style-dash-to-dock = lib.hm.gvariant.mkInt32 0;
      };

      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = true;
        static-blur = true;
        override-background = true;
        style-panel = lib.hm.gvariant.mkInt32 0;
      };

      "org/gnome/shell/extensions/blur-my-shell/overview" = {
        blur = true;
        style-components = lib.hm.gvariant.mkInt32 3;
      };

      # Blur application windows (for terminals, etc.)
      "org/gnome/shell/extensions/blur-my-shell/applications" = {
        blur = false;
        enable-all = true;
        brightness = 0.6;
        sigma = lib.hm.gvariant.mkInt32 15;
        dynamic-opacity = false; # Keep blur even when focused
        opacity = lib.hm.gvariant.mkInt32 230;
      };

      # Desktop icons settings (right-aligned, top-to-bottom like KDE)
      "org/gnome/nautilus/icon-view" = {
        default-zoom-level = "small";
      };

      # File chooser settings
      "org/gtk/gtk4/settings/file-chooser" = {
        sort-directories-first = true;
        show-hidden = false;
      };

      "org/gtk/settings/file-chooser" = {
        sort-directories-first = true;
        show-hidden = false;
      };

      # Power settings
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-type = "nothing";
      };

      # Pointer & touchpad settings
      "org/gnome/desktop/peripherals/touchpad" = {
        natural-scroll = true;
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
      };

      "org/gnome/desktop/peripherals/mouse" = {
        natural-scroll = true;
      };

      # GNOME Console
      "org/gnome/Console" = {
        theme = "night";
        use-system-font = false;
        custom-font = "Cascadia Mono PL 11";
        transparency = true;
        audible-bell = true;
        visual-bell = true;
      };
    };

    # GTK theme configuration (works for both GTK3 and GTK4)
    # This module handles cursor, icons, and theme - sets dconf keys automatically
    gtk = {
      enable = true;

      # Cursor theme and size (sets org/gnome/desktop/interface cursor-theme & cursor-size)
      cursorTheme = {
        name = "Adwaita";
        size = 24;
      };

      # Icon theme (sets org/gnome/desktop/interface icon-theme)
      iconTheme = {
        name = "Adwaita";
      };

      # GTK3 theme (sets org/gnome/desktop/interface gtk-theme)
      # adw-gtk3 makes GTK3 apps match libadwaita's look
      gtk3.theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };

      gtk4.theme = config.gtk.theme;

      # GTK3 settings
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-decoration-layout = "appmenu:minimize,maximize,close";
      };

      # GTK4 settings
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-decoration-layout = "appmenu:minimize,maximize,close";
      };
    };

    # GPG with pinentry-gnome3 for GNOME
    services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;

    # Additional packages
    home.packages = with pkgs; [
      dconf-editor
      file-roller
      gnome-console
      gnome-tweaks
    ];

    # Hack: fix .gtkrc-2.0 becoming a real file instead of a symlink (same as plasma)
    home.activation.rm-gtkrc-2-0 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ ! -L $HOME/.gtkrc-2.0 ]; then
        rm -f $HOME/.gtkrc-2.0
      fi
    '';
  };
}
