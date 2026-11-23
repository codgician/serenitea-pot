{
  lib,
  effectiveWallpaper,
  hasIioSensor,
  oskCtl,
  pinnedIds,
  userAvatar,
}:
{
  enable = true;
  systemd.enable = true;
  checkConfig = true;

  settings = {
    shell = {
      polkit_agent = true;
      setup_wizard_enabled = false;
      settings_window_translucent = true;
      launcher.pinned = pinnedIds;
      window_switcher.mru = true;
      panel = {
        transparency_mode = "glass";
        control_center_placement = "floating";
        wallpaper_placement = "floating";
        session_placement = "floating";
        open_near_click_control_center = true;
        open_near_click_wallpaper = true;
        open_near_click_session = true;
      };
    }
    // lib.optionalAttrs (userAvatar != null) {
      avatar_path = toString userAvatar;
    };

    wallpaper.default.path = toString effectiveWallpaper;

    theme = {
      mode = "dark";
      source = "wallpaper";
      wallpaper_scheme = "m3-tonal-spot";
      templates = {
        enable_builtin_templates = true;
        builtin_ids = [
          "gtk3"
          "gtk4"
          "qt"
          "kcolorscheme"
          "ghostty"
          "hyprland"
        ];
      };
    };

    nightlight = {
      enabled = true;
      temperature_day = 6500;
      temperature_night = 4500;
    };

    location = {
      custom_schedule = true;
      sunrise = "07:00";
      sunset = "20:00";
    };

    idle.behavior = {
      lock = {
        enabled = true;
        timeout = 600;
        action = "lock";
      };
      screen-off = {
        enabled = true;
        timeout = 660;
        action = "screen_off";
      };
    };

    dock = {
      enabled = true;
      margin_edge = 8;
      concave_edge_corners = false;
      background_opacity = 0.62;
      border = "outline_variant";
      border_width = 1.0;
      smart_auto_hide = true;
      auto_hide_reveal_delay_ms = 0;
      reserve_space = false;
      pinned = pinnedIds;
    };

    notification.background_opacity = 0.62;
    osd.background_opacity = 0.62;

    hooks.colors_changed = "hyprctl reload config-only";

    bar.default = {
      margin_ends = 0;
      margin_edge = 0;
      radius = 0;
      concave_edge_corners = false;
      background_opacity = 0.62;
      scale = 1.15;
      font_scale = 0.87;
      end = [
        "media"
        "tray"
        "notifications"
        "clipboard"
        "network"
        "bluetooth"
        "volume"
        "brightness"
        "battery"
      ]
      ++ lib.optionals hasIioSensor [
        "window_switcher_button"
        "osk_button"
      ]
      ++ [
        "control-center"
        "session"
      ];
    };

    widget = {
      clock.format = "{:%a %b %-d %-I:%M %p}";
      media = {
        album_art_only = true;
        hide_when_no_media = true;
      };
      tray.hide_passive = false;
      network.show_label = false;
      bluetooth.show_label = false;
      volume.show_label = false;
      brightness.show_label = false;
      battery = {
        display_mode = "graphic";
        show_label = true;
        scale = 0.85;
        font_scale = 1.15;
      };
    }
    // lib.optionalAttrs hasIioSensor {
      window_switcher_button = {
        type = "custom_button";
        glyph = "app-window";
        tooltip = "Window Switcher";
        actions.left = "window-switcher";
      };
      osk_button = {
        type = "custom_button";
        glyph = "keyboard";
        tooltip = "Toggle On-Screen Keyboard";
        actions.left = "exec ${oskCtl} toggle";
      };
    };
  };
}
