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
in
{
  options.codgician.codgi.gnome = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.services.desktopManager.gnome.enable or false;
      description = "Enable dotfiles for GNOME desktop.";
    };

    favoriteApps = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "org.gnome.Terminal.desktop"
      ]
      ++ (lib.optional (config.codgician.codgi.vscode.enable or false) "code.desktop");
      description = "List of .desktop file names to pin in the GNOME dock.";
    };
  };

  config = lib.mkIf cfg.enable {
    # GNOME Shell extensions
    programs.gnome-shell = {
      enable = true;
      extensions = [
        { package = pkgs.gnomeExtensions.blur-my-shell; }
        { package = pkgs.gnomeExtensions.dash-to-dock; }
        { package = pkgs.gnomeExtensions.appindicator; }
      ];
    };

    # dconf settings for GNOME-specific behavior only
    # Theme/cursor/icon settings are handled by gtk module below
    dconf.settings = {
      # Desktop interface - behavior settings only
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        enable-hot-corners = false;
        font-antialiasing = "rgba";
        font-hinting = "slight";
        # Accessibility: locate pointer on Ctrl press (like KDE shake cursor)
        locate-pointer = true;
      };

      # Window manager preferences
      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };

      # Favorite apps in dock (equivalent to plasma taskbar pinned apps)
      "org/gnome/shell" = {
        favorite-apps = cfg.favoriteApps;
      };

      # Dash-to-dock settings (macOS-like behavior)
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        extend-height = false;

        # macOS-like auto-hide behavior
        dock-fixed = false;
        autohide = true;
        intellihide = true;
        autohide-in-fullscreen = true;
        animation-time = 0.2;
        hide-delay = 0.2;
        show-delay = 0.0;
        pressure-threshold = 100.0;
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

      # Blur-my-shell settings (replicates KDE blur effect)
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.85;
        sigma = lib.hm.gvariant.mkInt32 15; # Match KDE blur strength
        noise-amount = 0.05; # Match KDE noise strength (5/100)
      };

      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = true;
        brightness = 0.6;
        sigma = lib.hm.gvariant.mkInt32 15;
        static-blur = true;
        style-dash-to-dock = lib.hm.gvariant.mkInt32 0;
      };

      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = true;
        brightness = 0.6;
        sigma = lib.hm.gvariant.mkInt32 15;
        static-blur = true;
      };

      "org/gnome/shell/extensions/blur-my-shell/overview" = {
        blur = true;
        style-components = lib.hm.gvariant.mkInt32 3;
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

      # Touchpad settings
      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
      };
    };

    # GNOME Terminal configuration (equivalent to Konsole)
    programs.gnome-terminal = {
      enable = true;
      themeVariant = "dark";
      profile = {
        "b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
          default = true;
          visibleName = "Default";
          font = "Cascadia Mono PL 11";
          # Semi-transparent background like breeze-blur
          transparencyPercent = 20;
        };
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

      # GTK theme (sets org/gnome/desktop/interface gtk-theme)
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };

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

    # Qt apps should follow GTK theme in GNOME
    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    # GPG with pinentry-gnome3 for GNOME
    services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;

    # Additional packages
    home.packages = with pkgs; [
      adw-gtk3
      adwaita-qt
      gnome-tweaks
      dconf-editor
    ];

    # Custom GNOME Shell CSS for transparent menus (works with blur-my-shell)
    xdg.configFile."gnome-shell/gnome-shell.css".text = ''
      /* Transparent popup menus (right-click, etc.) */
      .popup-menu-content {
        background-color: rgba(30, 30, 30, 0.6) !important;
        border: 1px solid rgba(255, 255, 255, 0.1);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
      }

      /* Submenus */
      .popup-sub-menu {
        background-color: rgba(255, 255, 255, 0.05) !important;
      }

      /* Menu arrow/pointer */
      .popup-menu-boxpointer {
        -arrow-background-color: rgba(30, 30, 30, 0.6);
        -arrow-border-color: rgba(255, 255, 255, 0.1);
      }
    '';

    # GTK4 CSS for transparent application menus (Nautilus, etc.)
    gtk.gtk4.extraCss = ''
      /* Transparent popovers/context menus */
      popover.menu contents {
        background-color: rgba(30, 30, 30, 0.6);
      }

      popover.menu menuitem:hover {
        background-color: rgba(255, 255, 255, 0.1);
      }
    '';

    # Hack: fix .gtkrc-2.0 becoming a real file instead of a symlink (same as plasma)
    home.activation.rm-gtkrc-2-0 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ ! -L $HOME/.gtkrc-2.0 ]; then
        rm -f $HOME/.gtkrc-2.0
      fi
    '';
  };
}
