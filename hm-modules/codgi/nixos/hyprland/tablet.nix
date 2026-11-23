{
  lib,
  pkgs,
  internalMonitor,
}:
let
  hyprctl = lib.getExe' pkgs.hyprland "hyprctl";
  monitorSensor = lib.getExe' pkgs.iio-sensor-proxy "monitor-sensor";
  notifySend = lib.getExe pkgs.libnotify;
  pkill = lib.getExe' pkgs.procps "pkill";
  sleep = lib.getExe' pkgs.coreutils "sleep";
  stdbuf = lib.getExe' pkgs.coreutils "stdbuf";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  wvkbd = lib.getExe' pkgs.wvkbd "wvkbd-mobintl";

  monitorScaleLua =
    if builtins.isString internalMonitor.scale then
      ''"${internalMonitor.scale}"''
    else
      toString internalMonitor.scale;

  mkTransformLua =
    {
      transform,
      extraConfig ? "",
    }:
    let
      extra = lib.optionalString (extraConfig != "") ", ${extraConfig}";
    in
    ''hl.monitor({ output = \"${internalMonitor.output}\", mode = \"${internalMonitor.mode}\", position = \"${internalMonitor.position}\", scale = ${monitorScaleLua}, transform = ${transform} }); hl.config({ input = { touchdevice = { transform = ${transform} }, tablet = { transform = ${transform} } }${extra} })'';

  # iio-hyprland uses legacy `hyprctl keyword`, which Hyprland 0.55+ rejects in Lua config mode.
  iioRotate = pkgs.writeShellScript "iio-hyprland-rotate" ''
    set -euo pipefail
    last=""
    apply_orientation() {
      local orientation="$1"
      local transform=""
      case "$orientation" in
        normal)    transform=0 ;;
        left-up)   transform=1 ;;
        bottom-up) transform=2 ;;
        right-up)  transform=3 ;;
        *) return 0 ;;
      esac
      if [ "$transform" = "$last" ]; then
        return 0
      fi
      if ${hyprctl} eval "${mkTransformLua { transform = "$transform"; }}"; then
        last="$transform"
      fi
    }

    ${stdbuf} -oL ${monitorSensor} --accel | while IFS= read -r line; do
      case "$line" in
        *"orientation: "*)
          rest="''${line#*orientation: }"
          apply_orientation "''${rest%%[,)]*}"
          ;;
        *"orientation changed: "*)
          apply_orientation "''${line#*orientation changed: }"
          ;;
      esac
    done
  '';

  wvkbdArgs = lib.concatStringsSep " " [
    "-L 340"
    "-H 420"
    "-R 8"
    "-l full,special,emoji"
    "--landscape-layers fullwide,special,emoji"
    ''--fn "Noto Sans 16"''
    "--bg 1a1c20"
    "--fg 2a2d34"
    "--fg-sp 23262c"
    "--press 3f4654"
    "--press-sp 3f4654"
    "--text e2e2e7"
    "--text-sp c4c7cf"
  ];

  oskCtl = pkgs.writeShellScript "tablet-osk-ctl" ''
    set -euo pipefail
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    pidfile="$runtime/tablet-osk-hide.pid"
    tablet_flag="$runtime/hyprland-tablet-mode"

    cancel_pending_hide() {
      if [ -f "$pidfile" ]; then
        kill "$(cat "$pidfile")" 2>/dev/null || true
        rm -f "$pidfile"
      fi
    }

    case "''${1:-toggle}" in
      show)
        cancel_pending_hide
        ${pkill} -SIGUSR2 -x wvkbd-mobintl 2>/dev/null || true
        ;;
      hide)
        cancel_pending_hide
        (
          my_pid="$BASHPID"
          ${sleep} 0.15
          if [ "$(cat "$pidfile" 2>/dev/null || true)" = "$my_pid" ]; then
            rm -f "$pidfile"
            ${pkill} -SIGUSR1 -x wvkbd-mobintl 2>/dev/null || true
          fi
        ) &
        echo $! > "$pidfile"
        ;;
      toggle)
        cancel_pending_hide
        if [ -f "$tablet_flag" ]; then
          ${pkill} -SIGRTMIN -x wvkbd-mobintl 2>/dev/null \
            || ${systemctl} --user start wvkbd.service
          exit 0
        fi
        if ${pkill} -x wvkbd-mobintl 2>/dev/null; then
          exit 0
        fi
        exec ${wvkbd} ${wvkbdArgs}
        ;;
    esac
  '';

  tabletModeCtl = pkgs.writeShellScript "hyprland-tablet-mode" ''
    set -euo pipefail
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    tablet_flag="$runtime/hyprland-tablet-mode"
    pidfile="$runtime/tablet-osk-hide.pid"

    case "''${1:-}" in
      enter)
        touch "$tablet_flag"
        ${systemctl} --user start iio-hyprland-rotate.service wvkbd.service
        ${hyprctl} eval "hl.config({ scrolling = { column_width = 1.0 } })" >/dev/null || true
        ${notifySend} -a "Tablet Mode" -t 2000 \
          -h string:x-canonical-private-synchronous:tablet-mode \
          "Tablet Mode" "Auto-rotation and on-screen keyboard enabled" || true
        ;;
      exit)
        if [ -f "$pidfile" ]; then
          kill "$(cat "$pidfile")" 2>/dev/null || true
          rm -f "$pidfile"
        fi
        rm -f "$tablet_flag"
        ${systemctl} --user stop iio-hyprland-rotate.service wvkbd.service || true
        ${pkill} -x wvkbd-mobintl 2>/dev/null || true
        ${hyprctl} eval "${
          mkTransformLua {
            transform = "0";
            extraConfig = "scrolling = { column_width = 0.65 }";
          }
        }" >/dev/null || true
        ${notifySend} -a "Tablet Mode" -t 2000 \
          -h string:x-canonical-private-synchronous:tablet-mode \
          "Laptop Mode" "Display locked to landscape" || true
        ;;
    esac
  '';

  hyprlandExtraConfig = ''

    do
      local ipc = "noctalia msg "
      local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or ""
      local tablet_flag = runtime_dir .. "/hyprland-tablet-mode"
      local osk_pidfile = runtime_dir .. "/tablet-osk-hide.pid"

      -- 360-degree hinge Tablet Mode switch (auto-rotation, OSK, single-column width)
      hl.bind("switch:on:Tablet Mode Switch",  hl.dsp.exec_cmd("${tabletModeCtl} enter"), { locked = true })
      hl.bind("switch:off:Tablet Mode Switch", hl.dsp.exec_cmd("${tabletModeCtl} exit"),  { locked = true })

      -- Preserve tablet-mode layout and orientation across `hyprctl reload config-only`.
      local flag = io.open(tablet_flag, "r")
      if flag then
        flag:close()
        hl.config({ scrolling = { column_width = 1.0 } })
        hl.exec_cmd("${systemctl} --user restart iio-hyprland-rotate.service")
      end

      hl.on("hyprland.shutdown", function()
        os.remove(tablet_flag)
        os.remove(osk_pidfile)
      end)

      -- Touchscreen gestures via hyprgrass (loaded on hyprland.start, configured after reload)
      if hl.plugin.hyprgrass then
        local dock_revealed_by_touch = false
        local function dismiss_touch_dock()
          if not dock_revealed_by_touch then
            return
          end
          local dock = hl.get_layers({ namespace = "noctalia-dock" })[1]
          if dock then
            hl.dispatch(hl.dsp.cursor.move({
              x = math.floor(dock.x + dock.w / 2),
              y = math.max(0, math.floor(dock.y - 40)),
            }))
          end
          dock_revealed_by_touch = false
        end

        hl.on("window.active", dismiss_touch_dock)

        hl.config({
          plugin = {
            hyprgrass = {
              sensitivity = 4.0,
              long_press_delay = 400,
              resize_on_border_long_press = true,
              edge_margin = 16,
              hold_touches = true,
              hold_touches_delay = 40,
            },
          },
        })

        hl.plugin.hyprgrass.gesture({
          pattern = { kind = "swipe", fingers = 3, direction = "horizontal" },
          action = "scroll_move",
        })
        hl.plugin.hyprgrass.gesture({
          pattern = { kind = "swipe", fingers = 4, direction = "horizontal" },
          action = "workspace",
        })
        hl.plugin.hyprgrass.gesture({
          pattern = { kind = "swipe", fingers = 3, direction = "down" },
          action = "close",
        })

        hl.plugin.hyprgrass.bind({
          pattern = { kind = "swipe", fingers = 3, direction = "up" },
          action = hl.dsp.exec_cmd(ipc .. "window-switcher"),
        })
        hl.plugin.hyprgrass.bind({
          pattern = { kind = "edge", origin = "down", direction = "up" },
          action = function()
            local dock = hl.get_layers({ namespace = "noctalia-dock" })[1]
            if not dock then
              return
            end
            local cur = hl.get_cursor_pos()
            local inside_dock = cur
              and cur.x >= dock.x and cur.x <= dock.x + dock.w
              and cur.y >= dock.y and cur.y <= dock.y + dock.h
            if inside_dock and dock_revealed_by_touch then
              dismiss_touch_dock()
            else
              dock_revealed_by_touch = true
              hl.dispatch(hl.dsp.cursor.move({
                x = math.floor(dock.x + dock.w / 2),
                y = math.floor(dock.y + dock.h - 1),
              }))
            end
          end,
        })
        hl.plugin.hyprgrass.bind({
          pattern = { kind = "edge", origin = "up", direction = "down" },
          action = hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"),
        })
        hl.plugin.hyprgrass.bind({
          pattern = { kind = "edge", origin = "left", direction = "right" },
          action = hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"),
        })
        hl.plugin.hyprgrass.bind({
          pattern = { kind = "longpress", fingers = 3 },
          action = hl.dsp.window.drag(),
          mouse = true,
        })
      end
    end
  '';

  fcitx5OskExtension = ''
    local fcitx = require("fcitx")

    local function in_tablet_mode()
      local runtime = os.getenv("XDG_RUNTIME_DIR")
      if not runtime or runtime == "" then
        return false
      end
      local f = io.open(runtime .. "/hyprland-tablet-mode", "r")
      if f then
        f:close()
        return true
      end
      return false
    end

    function tablet_osk_focus_in()
      if in_tablet_mode() then
        os.execute("${oskCtl} show >/dev/null 2>&1 &")
      end
    end

    function tablet_osk_focus_out()
      if in_tablet_mode() then
        os.execute("${oskCtl} hide >/dev/null 2>&1 &")
      end
    end

    fcitx.watchEvent(fcitx.EventType.FocusIn, "tablet_osk_focus_in")
    fcitx.watchEvent(fcitx.EventType.FocusOut, "tablet_osk_focus_out")
  '';

  systemdServices = {
    # Started and stopped by hyprland-tablet-mode rather than at session login.
    iio-hyprland-rotate = {
      Unit = {
        Description = "Auto-rotate Hyprland display, touch, and stylus from IIO accelerometer";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${iioRotate}";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    wvkbd = {
      Unit = {
        Description = "Hidden Wayland on-screen keyboard managed in tablet mode";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${wvkbd} --hidden ${wvkbdArgs}";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
in
{
  inherit
    fcitx5OskExtension
    hyprlandExtraConfig
    oskCtl
    systemdServices
    ;
}
