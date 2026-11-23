{
  lib,
  osConfig,
  pkgs,
  hasIioSensor,
  internalMonitor,
  tabletExtraConfig,
}:
{
  enable = true;
  package = null;
  portalPackage = null;
  plugins = lib.optional hasIioSensor pkgs.hyprlandPlugins.hyprgrass;
  configType = "lua";
  systemd.enable = false;

  settings = {
    monitor = osConfig.codgician.services.hyprland.monitors;

    env = [
      {
        _args = [
          "XCURSOR_THEME"
          "Adwaita"
        ];
      }
      {
        _args = [
          "XCURSOR_SIZE"
          "24"
        ];
      }
      {
        _args = [
          "HYPRCURSOR_SIZE"
          "24"
        ];
      }
    ];

    config = {
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 1;
        resize_on_border = true;
        layout = "scrolling";
        snap = {
          enabled = true;
          window_gap = 10;
          monitor_gap = 10;
        };
      };

      scrolling = {
        fullscreen_on_one_column = true;
        column_width = 0.65;
        explicit_column_widths = "0.5, 0.667, 0.85, 1.0";
        direction = "right";
        follow_focus = true;
      };

      decoration = {
        rounding = 12;
        rounding_power = 2;
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = true;
          xray = false;
          size = 6;
          passes = 3;
          vibrancy = 0.1696;
        };
      };

      animations.enabled = true;

      render = {
        cm_enabled = true;
        cm_auto_hdr = 1;
      };

      xwayland.force_zero_scaling = true;

      cursor = {
        hide_on_touch = true;
        hide_on_tablet = false;
      };

      gestures = {
        workspace_swipe_cancel_ratio = 0.15;
        workspace_swipe_use_r = true;
        workspace_swipe_create_new = true;
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        natural_scroll = true;
        touchpad = {
          natural_scroll = true;
          clickfinger_behavior = true;
          tap_to_click = true;
        };
      }
      // lib.optionalAttrs hasIioSensor {
        touchdevice = {
          output = internalMonitor.output;
          transform = 0;
        };
        tablet = {
          output = internalMonitor.output;
          transform = 0;
        };
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        force_default_wallpaper = 0;
        focus_on_activate = true;
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        allow_session_lock_restore = true;
        key_press_enables_dpms = true;
        mouse_move_enables_dpms = true;
        vrr = 2;
      };
    };

    gesture = [
      {
        fingers = 3;
        direction = "horizontal";
        action = "scroll_move";
      }
      {
        fingers = 4;
        direction = "horizontal";
        action = "workspace";
      }
    ];

    layer_rule = [
      {
        # Noctalia animates its own surfaces; compositor layer animations cause tearing.
        name = "noctalia-no-anim";
        match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
        no_anim = true;
      }
      {
        name = "noctalia-blur";
        match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
        ignore_alpha = 0.5;
        blur = true;
        blur_popups = true;
      }
    ];

    window_rule = [
      {
        name = "suppress-maximize-events";
        match.class = ".*";
        suppress_event = "maximize";
      }
      {
        name = "noctalia-settings";
        match.class = "dev.noctalia.Noctalia";
        float = true;
        center = true;
        size = "monitor_w*0.5625 monitor_h*0.85";
      }
      {
        name = "float-dialogs";
        match.class = "^(microsoft-identity-broker|xdg-desktop-portal-gtk|nwg-displays|hyprpwcenter|org\\.gnome\\.FileRoller|nm-connection-editor)$";
        float = true;
        center = true;
      }
      {
        name = "fix-xwayland-drags";
        match = {
          class = "^$";
          title = "^$";
          xwayland = true;
          float = true;
          fullscreen = false;
          pin = false;
        };
        no_focus = true;
      }
    ];
  };

  extraConfig = ''
    -- Critically-damped springs (defined before hl.animation; HM sorts settings keys alphabetically).
    -- Hyprland's Lua API still requires speed > 0 on spring animations.
    hl.curve("spring_snappy", { type = "spring", mass = 1, stiffness = 480, damping = 44 })
    hl.curve("spring_smooth", { type = "spring", mass = 1, stiffness = 360, damping = 38 })

    hl.animation({ leaf = "global",           enabled = true, speed = 1, spring = "spring_snappy" })
    hl.animation({ leaf = "windowsIn",        enabled = true, speed = 1, spring = "spring_snappy", style = "popin 85%" })
    hl.animation({ leaf = "windowsOut",       enabled = true, speed = 1, spring = "spring_snappy", style = "popin 85%" })
    hl.animation({ leaf = "windowsMove",      enabled = true, speed = 1, spring = "spring_snappy" })
    hl.animation({ leaf = "workspaces",       enabled = true, speed = 1, spring = "spring_smooth", style = "slide" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1, spring = "spring_smooth", style = "slidevert" })

    local mainMod = "SUPER"
    local ipc = "noctalia msg "

    -- Core apps & Noctalia shell panels
    hl.bind(mainMod .. " + SPACE",  hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))
    hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("ghostty"))
    hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("nautilus"))
    hl.bind(mainMod .. " + L",      hl.dsp.exec_cmd(ipc .. "session lock"))
    hl.bind(mainMod .. " + N",      hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
    hl.bind(mainMod .. " + C",      hl.dsp.exec_cmd(ipc .. "panel-toggle clipboard"))
    hl.bind(mainMod .. " + comma",  hl.dsp.exec_cmd(ipc .. "settings-toggle"))
    hl.bind(mainMod .. " + P",      hl.dsp.exec_cmd(ipc .. "screenshot-region"))
    hl.bind("Print",                hl.dsp.exec_cmd(ipc .. "screenshot-region"))
    hl.bind(mainMod .. " + A",      hl.dsp.exec_cmd("hyprpwcenter"))
    hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd("nwg-displays"))

    -- Window & scrolling-layout management
    hl.bind(mainMod .. " + Q",         hl.dsp.window.close())
    hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
    hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = 1 }))
    hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))
    hl.bind(mainMod .. " + R",         hl.dsp.layout("colresize +conf"))
    hl.bind(mainMod .. " + SHIFT + R", hl.dsp.layout("colresize -conf"))
    hl.bind(mainMod .. " + M",         hl.dsp.window.move({ workspace = "special:minimized", silent = true }))
    hl.bind(mainMod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))

    -- Window switching (Noctalia carousel switcher)
    hl.bind("ALT + Tab",             hl.dsp.exec_cmd(ipc .. "window-switcher hold"))
    hl.bind("ALT + SHIFT + Tab",     hl.dsp.exec_cmd(ipc .. "window-switcher hold reverse"))
    hl.bind(mainMod .. " + Tab",     hl.dsp.exec_cmd(ipc .. "window-switcher"))

    -- Vertical trackpad gestures (horizontal 3fg scroll_move & 4fg workspace are in settings.gesture)
    hl.gesture({
      fingers = 3,
      direction = "up",
      action = function()
        hl.exec_cmd(ipc .. "window-switcher")
      end,
    })
    hl.gesture({
      fingers = 3,
      direction = "down",
      action = function()
        hl.exec_cmd(ipc .. "panel-toggle launcher")
      end,
    })

    -- Focus & column order
    hl.bind(mainMod .. " + left",          hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right",         hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",            hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",          hl.dsp.focus({ direction = "down" }))
    hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.layout("swapcol l"))
    hl.bind(mainMod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))

    for i = 1, 9 do
      hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
      hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    end

    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Media & hardware keys routed through Noctalia for unified OSD feedback
    hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. "volume-up"),       { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. "volume-down"),     { locked = true, repeating = true })
    hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. "volume-mute"),     { locked = true })
    hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(ipc .. "mic-mute"),        { locked = true })
    hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. "brightness-up"),   { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"), { locked = true, repeating = true })
    hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(ipc .. "media next"),      { locked = true })
    hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(ipc .. "media toggle"),    { locked = true })
    hl.bind("XF86AudioPause",        hl.dsp.exec_cmd(ipc .. "media toggle"),    { locked = true })
    hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd(ipc .. "media previous"),  { locked = true })

    -- Apply dynamic colors generated by Noctalia's Hyprland template when present;
    -- keeping `require("noctalia")` here prevents apply.sh from modifying this symlink.
    pcall(function()
      package.loaded["noctalia"] = nil
      require("noctalia").apply_theme()
    end)
  ''
  + lib.optionalString hasIioSensor tabletExtraConfig;
}
