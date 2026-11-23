{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.hyprland;
  types = lib.types;

  defaultWallpaper = "${pkgs.hyprland}/share/hypr/wall2.png";
  effectiveWallpaper = if cfg.wallpaper != null then cfg.wallpaper else defaultWallpaper;

  hasIioSensor = osConfig.hardware.sensor.iio.enable or false;
  hasFcitx5 = osConfig.codgician.services.fcitx5.enable or false;
  userAvatar = osConfig.codgician.users.codgi.avatar or null;
  pinnedIds = map (lib.removeSuffix ".desktop") cfg.favoriteApps;

  explicitMonitors = builtins.filter (m: m.output != "") (
    osConfig.codgician.services.hyprland.monitors or [ ]
  );
  internalMonitor =
    if explicitMonitors != [ ] then
      builtins.head explicitMonitors
    else
      {
        output = "eDP-1";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      };

  tablet = import ./tablet.nix {
    inherit lib pkgs internalMonitor;
  };

  qtctFormat = pkgs.formats.ini {
    listToValue = lib.concatStringsSep ", ";
  };
  mkQtctConfig =
    {
      dir,
      style,
    }:
    qtctFormat.generate "${dir}.conf" {
      Appearance = {
        color_scheme_path = "${config.xdg.configHome}/${dir}/colors/noctalia.conf";
        custom_palette = true;
        icon_theme = "Adwaita";
        standard_dialogs = "xdgdesktopportal";
        inherit style;
      };
      Fonts = {
        fixed = ''"Cascadia Mono PL,11"'';
        general = ''"Noto Sans,10"'';
      };
    };
in
{
  options.codgician.codgi.hyprland = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.codgician.services.hyprland.enable or false;
      description = "Enable the unified Hyprland + Noctalia desktop session.";
    };

    favoriteApps = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "org.gnome.Nautilus.desktop"
        "firefox.desktop"
        "com.mitchellh.ghostty.desktop"
      ]
      ++ (lib.optional (config.codgician.codgi.vscode.enable or false) "code.desktop");
      description = "List of .desktop file names to pin in the Noctalia dock and launcher.";
    };

    wallpaper = lib.mkOption {
      type = types.nullOr types.path;
      default = osConfig.codgician.services.hyprland.wallpaper or null;
      description = "Wallpaper shared by the Hyprland desktop and Noctalia lock screen.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.noctalia = import ./noctalia.nix {
      inherit
        lib
        effectiveWallpaper
        hasIioSensor
        pinnedIds
        userAvatar
        ;
      inherit (tablet) oskCtl;
    };

    wayland.windowManager.hyprland = import ./hyprland.nix {
      inherit
        lib
        osConfig
        pkgs
        hasIioSensor
        internalMonitor
        ;
      tabletExtraConfig = tablet.hyprlandExtraConfig;
    };

    xdg = {
      configFile = {
        # Plasma's kde-gtk-config writes real gtk.css files; force-replace when switching to Hyprland.
        "gtk-3.0/gtk.css".force = true;
        "gtk-4.0/gtk.css".force = true;
        "hypr/hyprland.lua".force = true;
        "noctalia/config.toml".force = true;
        "qt5ct/qt5ct.conf" = {
          force = true;
          source = mkQtctConfig {
            dir = "qt5ct";
            style = "Breeze";
          };
        };
        "qt6ct/qt6ct.conf" = {
          force = true;
          source = mkQtctConfig {
            dir = "qt6ct";
            style = "Darkly";
          };
        };
        "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
        "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
      };
      dataFile = lib.optionalAttrs (hasIioSensor && hasFcitx5) {
        "fcitx5/lua/imeapi/extensions/tablet-osk.lua".text = tablet.fcitx5OskExtension;
      };
      mimeApps.defaultApplications = {
        "inode/directory" = "org.gnome.Nautilus.desktop";
        "application/pdf" = "org.gnome.Papers.desktop";
        "image/png" = "org.gnome.Loupe.desktop";
        "image/jpeg" = "org.gnome.Loupe.desktop";
        "image/webp" = "org.gnome.Loupe.desktop";
        "image/gif" = "org.gnome.Loupe.desktop";
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-theme = "Adwaita";
        cursor-size = 24;
        icon-theme = "Adwaita";
        font-antialiasing = "rgba";
        font-hinting = "slight";
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = ":close";
      };

      "org/gnome/nautilus/icon-view" = {
        default-zoom-level = "small";
      };

      "org/gtk/gtk4/settings/file-chooser" = {
        sort-directories-first = true;
        show-hidden = false;
      };

      "org/gtk/settings/file-chooser" = {
        sort-directories-first = true;
        show-hidden = false;
      };
    };

    gtk = {
      enable = true;
      cursorTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
      };
      iconTheme = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
      };
      gtk3 = {
        theme = {
          name = "adw-gtk3-dark";
          package = pkgs.adw-gtk3;
        };
        extraConfig = {
          gtk-application-prefer-dark-theme = true;
          gtk-decoration-layout = ":close";
        };
        # Pre-declare Noctalia's import so gtk/apply.sh leaves this Nix symlink intact.
        extraCss = ''
          @import url("noctalia.css");
        '';
      };
      gtk4 = {
        theme = config.gtk.theme;
        extraConfig = {
          gtk-application-prefer-dark-theme = true;
          gtk-decoration-layout = ":close";
        };
        extraCss = ''
          @import url("noctalia.css");
        '';
      };
    };

    home = {
      pointerCursor = {
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
        TERMINAL = "ghostty";
      };
      packages =
        with pkgs;
        [
          brightnessctl
          file-roller
          loupe
          nautilus
          networkmanagerapplet
          nwg-displays
          papers
          playerctl
          wl-clipboard
        ]
        ++ lib.optional hasIioSensor pkgs.wvkbd;

      # Hack: fix .gtkrc-2.0 becoming a real file instead of a symlink (same as plasma/gnome)
      activation.rm-gtkrc-2-0 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ ! -L $HOME/.gtkrc-2.0 ]; then
          rm -f $HOME/.gtkrc-2.0
        fi
      '';
    };

    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        font-family = "Cascadia Mono PL";
        font-size = 11;
        # Matches Noctalia's ghostty template so apply.sh leaves this Nix symlink intact.
        theme = "noctalia";
        background-opacity = 0.90;
        gtk-titlebar-style = "tabs";
        window-decoration = "auto";
        window-padding-x = 10;
        window-padding-y = 8;
        confirm-close-surface = false;
      };
    };

    services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;

    systemd.user.services = lib.mkIf hasIioSensor tablet.systemdServices;
  };
}
