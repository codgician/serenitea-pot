{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.hyprland;
  wallpaper = "${pkgs.hyprland}/share/hypr/wall2.png";
in
{
  options.codgician.codgi.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = osConfig.codgician.services.hyprland.enable or false;
      description = "Enable the macOS-inspired Hyprland session.";
    };

  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      configType = "lua";
      systemd.enable = false;

      settings = {
        monitor = osConfig.codgician.services.hyprland.monitors;

        env = [
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
            gaps_in = 6;
            gaps_out = 12;
            border_size = 1;
            resize_on_border = true;
            layout = "dwindle";
            col = {
              active_border = "rgba(8aadf4ee)";
              inactive_border = "rgba(6e738d88)";
            };
          };

          decoration = {
            rounding = 14;
            rounding_power = 2;
            active_opacity = 1.0;
            inactive_opacity = 0.96;
            shadow = {
              enabled = true;
              range = 18;
              render_power = 3;
              color = "rgba(00000066)";
            };
            blur = {
              enabled = true;
              size = 10;
              passes = 3;
              vibrancy = 0.18;
              popups = true;
            };
          };

          animations.enabled = true;

          dwindle = {
            preserve_split = true;
            smart_split = false;
          };

          input = {
            kb_layout = "us";
            follow_mouse = 1;
            touchpad = {
              natural_scroll = true;
              clickfinger_behavior = true;
              tap_to_click = true;
            };
          };

          misc = {
            disable_hyprland_logo = true;
            force_default_wallpaper = 0;
            focus_on_activate = true;
          };
        };

        gesture = {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        };

        window_rule = [
          {
            name = "suppress-maximize-events";
            match.class = ".*";
            suppress_event = "maximize";
          }
          {
            name = "float-dialogs";
            match = {
              class = "^(org\\.kde\\.polkit-kde-authentication-agent-1|org\\.freedesktop\\.impl\\.portal\\.desktop\\.kde)$";
            };
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
        local mainMod = "SUPER"

        hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprlauncher"))
        hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("ghostty"))
        hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
        hl.bind(mainMod .. " + Q", hl.dsp.window.close())
        hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
        hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
        hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
        hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("hyprpwcenter"))
        hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent special:minimized"))
        hl.bind(mainMod .. " + SHIFT + M", hl.dsp.workspace.toggle_special("minimized"))
        hl.bind(mainMod .. " + TAB", hl.dsp.window.cycle_next())
        hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

        hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
        hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
        hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
        hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

        for i = 1, 9 do
          hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
          hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
        end

        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
        hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
        hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
        hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
      '';
    };

    xdg = {
      configFile = {
        "hypr/hyprland.lua".force = true;
        "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
        "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
      };
      mimeApps.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
    };

    services = {
      hyprlauncher = {
        enable = true;
        settings = {
          general.grab_focus = true;
          cache.enabled = true;
          finders = {
            desktop_icons = true;
            math_prefix = "=";
            unicode_prefix = ".";
          };
          ui.window_size = "560 360";
        };
      };

      hyprpaper = {
        enable = true;
        settings = {
          splash = false;
          wallpaper = [
            {
              monitor = "";
              path = wallpaper;
              fit_mode = "cover";
            }
          ];
        };
      };

      hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on";
          };
          listener = [
            {
              timeout = 600;
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 630;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };

      hyprpolkitagent.enable = true;

      hyprsunset = {
        enable = true;
        settings.profile = [
          {
            time = "07:00";
            identity = true;
          }
          {
            time = "20:00";
            temperature = 4500;
            gamma = 0.9;
          }
        ];
      };

      swaync = {
        enable = true;
        settings = {
          positionX = "right";
          positionY = "top";
          layer = "overlay";
          control-center-layer = "top";
          layer-shell = true;
          control-center-width = 420;
          control-center-margin-top = 44;
          control-center-margin-bottom = 12;
          control-center-margin-right = 12;
          control-center-margin-left = 12;
          notification-icon-size = 48;
          notification-body-image-height = 120;
          notification-body-image-width = 220;
          timeout = 8;
          timeout-low = 4;
          timeout-critical = 0;
          widgets = [
            "title"
            "dnd"
            "mpris"
            "notifications"
          ];
        };
        style = ''
          * {
            font-family: "Noto Sans", sans-serif;
            color: #cad3f5;
          }

          .control-center {
            background: rgba(24, 25, 38, 0.92);
            border: 1px solid rgba(138, 173, 244, 0.35);
            border-radius: 18px;
            padding: 10px;
          }

          .notification-row {
            outline: none;
          }

          .notification {
            background: rgba(36, 39, 58, 0.96);
            border: 1px solid rgba(110, 115, 141, 0.45);
            border-radius: 14px;
            margin: 6px;
            padding: 4px;
          }

          .notification-content {
            padding: 8px;
          }

          .widget-title,
          .widget-dnd,
          .widget-mpris {
            background: rgba(54, 58, 79, 0.82);
            border-radius: 12px;
            margin: 6px;
            padding: 10px;
          }
        '';
      };
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = "Adwaita";
      cursor-size = 24;
      icon-theme = "Adwaita";
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
        extraConfig.gtk-application-prefer-dark-theme = true;
      };
      gtk4 = {
        theme = config.gtk.theme;
        extraConfig.gtk-application-prefer-dark-theme = true;
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
    };

    programs = {
      ghostty = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          font-family = "Cascadia Mono PL";
          font-size = 11;
          theme = "Catppuccin Mocha";
          background-opacity = 0.94;
          gtk-titlebar-style = "tabs";
          window-decoration = "auto";
          window-padding-x = 10;
          window-padding-y = 8;
          confirm-close-surface = false;
        };
      };

      hyprlock = {
        enable = true;
        settings = {
          general = {
            hide_cursor = true;
            immediate_render = true;
          };
          background = [
            {
              path = wallpaper;
              blur_passes = 4;
              blur_size = 8;
              brightness = 0.55;
            }
          ];
          label = [
            {
              monitor = "";
              text = "cmd[update:1000] date +'%H:%M'";
              color = "rgb(cad3f5)";
              font_size = 84;
              font_family = "Noto Sans";
              position = "0, 160";
              halign = "center";
              valign = "center";
            }
            {
              monitor = "";
              text = "cmd[update:60000] date +'%A, %B %-d'";
              color = "rgb(cad3f5)";
              font_size = 22;
              font_family = "Noto Sans";
              position = "0, 92";
              halign = "center";
              valign = "center";
            }
          ];
          "input-field" = [
            {
              monitor = "";
              size = "300, 54";
              position = "0, -80";
              dots_center = true;
              fade_on_empty = false;
              font_color = "rgb(cad3f5)";
              inner_color = "rgba(24273acc)";
              outer_color = "rgba(8aadf4cc)";
              outline_thickness = 2;
              rounding = 18;
              placeholder_text = ''<span foreground="##a5adcb">Password</span>'';
              shadow_passes = 2;
            }
          ];
        };
      };

      waybar = {
        enable = true;
        systemd.enable = true;
        settings = {
          menu = {
            name = "menu";
            layer = "top";
            position = "top";
            height = 32;
            margin = "6 10 0 10";
            modules-left = [
              "custom/launcher"
              "hyprland/window"
            ];
            modules-center = [ "clock" ];
            modules-right = [
              "tray"
              "pulseaudio"
              "network"
              "battery"
              "custom/notification"
            ];

            "custom/launcher" = {
              format = "";
              tooltip = false;
              on-click = "hyprlauncher";
            };
            "hyprland/window" = {
              max-length = 60;
              separate-outputs = true;
            };
            clock = {
              format = "{:%a %b %d  %I:%M %p}";
              tooltip-format = "<tt>{calendar}</tt>";
              calendar.mode = "month";
            };
            tray.spacing = 8;
            pulseaudio = {
              format = "{icon} {volume}%";
              format-muted = "󰖁";
              format-icons.default = [
                ""
                ""
                ""
              ];
              on-click = "hyprpwcenter";
            };
            network = {
              format-wifi = "  {signalStrength}%";
              format-ethernet = "󰈀";
              format-disconnected = "󰖪";
              tooltip-format = "{ifname}: {ipaddr}/{cidr}";
              on-click = "nm-connection-editor";
            };
            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{icon} {capacity}%";
              format-charging = "󰂄 {capacity}%";
              format-icons = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            "custom/notification" = {
              exec = "swaync-client -swb";
              return-type = "json";
              escape = true;
              format = "{icon}";
              format-icons = {
                notification = "󱅫";
                none = "󰂚";
                dnd-notification = "󰂛";
                dnd-none = "󰂛";
              };
              on-click = "swaync-client -t -sw";
              on-click-right = "swaync-client -d -sw";
            };
          };

          dock = {
            name = "dock";
            layer = "top";
            position = "bottom";
            height = 58;
            margin = "0 0 10 0";
            exclusive = false;
            modules-center = [
              "custom/files"
              "custom/browser"
              "custom/terminal"
              "custom/code"
              "wlr/taskbar"
            ];
            "custom/files" = {
              format = "󰉋";
              tooltip = true;
              tooltip-format = "Files";
              on-click = "nautilus";
            };
            "custom/browser" = {
              format = "󰈹";
              tooltip = true;
              tooltip-format = "Browser";
              on-click = "microsoft-edge";
            };
            "custom/terminal" = {
              format = "";
              tooltip = true;
              tooltip-format = "Terminal";
              on-click = "ghostty";
            };
            "custom/code" = {
              format = "󰨞";
              tooltip = true;
              tooltip-format = "Visual Studio Code";
              on-click = "code";
            };
            "wlr/taskbar" = {
              icon-size = 38;
              all-outputs = false;
              active-first = true;
              on-click = "activate";
              on-click-middle = "close";
              tooltip-format = "{title}";
            };
          };
        };
        style = ''
          * {
            border: none;
            border-radius: 0;
            min-height: 0;
            font-family: "Noto Sans", "Symbols Nerd Font Mono", sans-serif;
            font-size: 13px;
          }

          window#waybar.menu {
            background: rgba(24, 25, 38, 0.88);
            color: #cad3f5;
            border: 1px solid rgba(110, 115, 141, 0.35);
            border-radius: 11px;
          }

          window#waybar.dock {
            background: transparent;
          }

          window#waybar.dock .modules-center {
            background: rgba(24, 25, 38, 0.86);
            border: 1px solid rgba(110, 115, 141, 0.4);
            border-radius: 18px;
            padding: 5px 8px;
          }

          #custom-launcher,
          #window,
          #clock,
          #tray,
          #pulseaudio,
          #network,
          #battery,
          #custom-notification {
            padding: 0 10px;
          }

          #custom-launcher {
            color: #8aadf4;
            font-size: 17px;
          }

          #custom-files,
          #custom-browser,
          #custom-terminal,
          #custom-code,
          #taskbar button {
            color: #cad3f5;
            background: transparent;
            border-radius: 12px;
            font-size: 34px;
            margin: 0 3px;
            padding: 3px 7px;
          }

          #custom-files:hover,
          #custom-browser:hover,
          #custom-terminal:hover,
          #custom-code:hover,
          #taskbar button:hover {
            background: rgba(138, 173, 244, 0.22);
          }

          #taskbar button.active {
            background: rgba(138, 173, 244, 0.28);
            box-shadow: inset 0 -3px #8aadf4;
          }

          #battery.warning {
            color: #eed49f;
          }

          #battery.critical {
            color: #ed8796;
          }

          tooltip {
            background: rgba(24, 25, 38, 0.96);
            border: 1px solid rgba(138, 173, 244, 0.4);
            border-radius: 10px;
          }
        '';
      };
    };

    home.packages = with pkgs; [
      brightnessctl
      nautilus
      networkmanagerapplet
      playerctl
      wl-clipboard
    ];
  };
}
