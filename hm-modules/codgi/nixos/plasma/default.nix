{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.codgi.plasma;
  types = lib.types;
  uniform = names: value: lib.genAttrs names (_: value);
  allSides = uniform [
    "top"
    "right"
    "bottom"
    "left"
  ];
  allCorners = uniform [
    "topLeft"
    "topRight"
    "bottomRight"
    "bottomLeft"
  ];

  mkGlassSettings =
    {
      margin,
      radius ? 8,
    }:
    {
      panel.normal = {
        enabled = true;
        blurBehind = true;
        backgroundColor = {
          enabled = true;
          alpha = 0.55;
          sourceType = 1;
          systemColor = "backgroundColor";
          systemColorSet = "Window";
        };
        radius = {
          enabled = true;
          corner = allCorners radius;
        };
        margin = {
          enabled = true;
          side = margin;
        };
        border = {
          enabled = true;
          width = 1;
          color = {
            enabled = true;
            alpha = 0.12;
            sourceType = 0;
            custom = "#FFFFFF";
          };
        };
      };
      nativePanel.background = {
        enabled = true;
        opacity = 0.01;
        shadow = false;
      };
    };

  mkPanelColorizer = settings: extra: {
    plasmaPanelColorizer = {
      general = {
        enable = true;
        hideWidget = true;
      };
      settings.General = {
        globalSettings = builtins.toJSON settings;
      }
      // extra;
    };
  };

  mkTopPanelSettings =
    radius:
    lib.recursiveUpdate
      (mkGlassSettings {
        margin = allSides 0;
        inherit radius;
      })
      {
        panel.normal.padding = {
          enabled = true;
          side = (allSides 0) // {
            right = 4;
            left = 4;
          };
        };
        widgets.normal = {
          enabled = true;
          margin = {
            enabled = true;
            side = (allSides 0) // {
              top = 5;
              bottom = 5;
            };
          };
          spacing = 4;
        };
      };

  topPanelFloatingSettings = mkTopPanelSettings 8;
  topPanelAttachedSettings = mkTopPanelSettings 0;
  mkPreset =
    settings:
    pkgs.writeTextDir "settings.json" (
      builtins.toJSON {
        globalSettings = settings;
      }
    );

  topPanelColorizer = mkPanelColorizer topPanelFloatingSettings {
    animatePropertyChanges = true;
    animationDuration = 200;
    presetAutoloading = builtins.toJSON {
      enabled = true;
      filterByScreen = true;
      floating = "${mkPreset topPanelFloatingSettings}";
      normal = "${mkPreset topPanelAttachedSettings}";
    };
  };
  dockPanelColorizer = mkPanelColorizer (mkGlassSettings {
    margin = allSides 6;
  }) { };

in
{
  options.codgician.codgi.plasma = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.services.desktopManager.plasma6.enable;
      description = "Enable dotfiles for KDE plasma desktop.";
    };

    krdp = {
      enable = lib.mkEnableOption "the KRDP server for this Plasma session";

      port = lib.mkOption {
        type = types.port;
        default = 3389;
        description = "TCP port on which KRDP listens.";
      };

      quality = lib.mkOption {
        type = types.ints.between 0 100;
        default = 75;
        description = "Video encoding quality from 0 (lowest) to 100 (highest).";
      };
    };

    launchers = lib.mkOption {
      type = with types; listOf str;
      default = [
        "applications:org.kde.dolphin.desktop"
        "applications:firefox.desktop"
        "applications:org.kde.konsole.desktop"
        "applications:code.desktop"
      ];
      description = "Items to pin in launcher.";
    };

    wallpaper = lib.mkOption {
      type = with types; nullOr path;
      default = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Flow";
      description = "Wallpaper shared by the Plasma desktop and lock screen.";
    };

    scale = lib.mkOption {
      type = types.nullOr (types.addCheck types.number (x: x > 0));
      default = null;
      example = 2;
      description = "Global display scale for Plasma and XWayland applications.";
    };

    wallpaperFillMode = lib.mkOption {
      type =
        with types;
        nullOr (enum [
          "stretch"
          "preserveAspectFit"
          "preserveAspectCrop"
          "tile"
          "tileVertically"
          "tileHorizontally"
          "pad"
        ]);
      default = "preserveAspectCrop";
      description = "How Plasma scales the configured wallpaper.";
    };
  };

  config = lib.mkIf cfg.enable {

    programs.plasma = {
      enable = true;
      # Plasma stores desktop and lock-screen wallpapers separately.
      kscreenlocker.appearance.wallpaper = lib.mkIf (cfg.wallpaper != null) cfg.wallpaper;

      fonts = {
        general = {
          family = "Noto Sans";
          pointSize = 10;
        };
      };

      kwin = {
        effects = {
          blur = {
            enable = true;
            noiseStrength = 5;
            strength = 15;
          };
          shakeCursor.enable = true;
          snapHelper.enable = true;
        };

        titlebarButtons = {
          left = [ ];
          right = [
            "minimize"
            "maximize"
            "close"
          ];
        };
      };

      panels = [
        # Nix + metrics | weather + clock + notes | tray + notifications + desktop
        {
          location = "top";
          height = 32;
          floating = true;
          opacity = "translucent";
          alignment = "center";
          lengthMode = "fill";
          hiding = "normalpanel";
          widgets = [
            {
              panelSpacer = {
                expanding = false;
                length = 2;
              };
            }
            {
              name = "org.kde.plasma.kickoff";
              config.General.icon = "nix-snowflake-white";
            }
            {
              panelSpacer = {
                expanding = false;
                length = 6;
              };
            }
            {
              systemMonitor = {
                title = "System";
                showTitle = false;
                displayStyle = "org.kde.ksysguard.textonly";
                sensors = [
                  {
                    name = "cpu/all/usage";
                    color = "101,180,255";
                    label = "CPU:";
                  }
                  {
                    name = "memory/physical/usedPercent";
                    color = "130,210,130";
                    label = "RAM:";
                  }
                  {
                    name = "gpu/gpu1/usage";
                    color = "210,140,255";
                    label = "GPU:";
                  }
                ];
              };
            }
            {
              panelSpacer.expanding = true;
            }
            {
              name = "org.kde.plasma.weather";
              config = {
                WeatherStation = {
                  provider = "wettercom";
                  placeInfo = "place|Suzhou, Jiangsu Sheng, CN|extra|CN0JS0008;Suzhou";
                  placeDisplayName = "Suzhou, Jiangsu Sheng, CN";
                  updateInterval = 30;
                };
                Appearance.showTemperatureInCompactMode = true;
                Units = {
                  temperatureUnit = 6001; # Celsius
                  pressureUnit = 5007; # Kilopascal
                  speedUnit = 9001; # Kilometer per hour
                  visibilityUnit = 2007; # Kilometer
                };
              };
            }
            {
              panelSpacer = {
                expanding = false;
                length = 4;
              };
            }
            {
              digitalClock = {
                time = {
                  format = "12h";
                  showSeconds = "never";
                };
                calendar.firstDayOfWeek = "monday";
                date = {
                  enable = true;
                  format.custom = "ddd MMM d";
                  position = "besideTime";
                };
                font = {
                  family = "Noto Sans";
                  weight = 400;
                  size = if cfg.scale == 1 then 18 else 9;
                };
              };
            }
            {
              panelSpacer = {
                expanding = false;
                length = 4;
              };
            }
            {
              name = "org.kde.plasma.notes";
              config.General = {
                color = "translucent";
                fontSize = 12;
                pinOpen = false;
              };
            }
            {
              panelSpacer.expanding = true;
            }
            {
              systemTray = {
                icons = {
                  scaleToFit = false;
                  spacing = "medium";
                };
                items.hidden = [ "org.kde.plasma.notifications" ];
              };
            }
            "org.kde.plasma.notifications"
            {
              panelSpacer = {
                expanding = false;
                length = 2;
              };
            }
            topPanelColorizer
          ];
        }

        # Bottom dock: centered, fits content, hides under windows (macOS feel)
        {
          location = "bottom";
          height = 72;
          floating = true;
          alignment = "center";
          lengthMode = "fit";
          hiding = "dodgewindows";
          widgets = [
            {
              iconTasks = {
                inherit (cfg) launchers;
                appearance = {
                  fill = false;
                  showTooltips = true;
                  indicateAudioStreams = true;
                  iconSpacing = "medium";
                  rows = {
                    maximum = 1;
                    multirowView = "never";
                  };
                };
                behavior = {
                  grouping.method = "byProgramName";
                  sortingMethod = "manually";
                  showTasks = {
                    onlyInCurrentScreen = false;
                    onlyInCurrentDesktop = false;
                    onlyInCurrentActivity = true;
                  };
                };
              };
            }
            dockPanelColorizer
          ];
        }
      ];

      desktop.icons = {
        alignment = "right";
        arrangement = "topToBottom";
      };

      workspace = {
        wallpaper = lib.mkIf (cfg.wallpaper != null) cfg.wallpaper;
        wallpaperFillMode = lib.mkIf (cfg.wallpaperFillMode != null) cfg.wallpaperFillMode;
        cursor = {
          theme = "Breeze";
          size = 24;
        };

        # Configure Breeze explicitly so switching from another theme also
        # resets the persisted Plasma appearance settings.
        colorScheme = "BreezeDark";
        theme = "breeze-dark";
        splashScreen.theme = "org.kde.Breeze";
        iconTheme = "breeze-dark";
        widgetStyle = "Breeze";
        windowDecorations = {
          library = "org.kde.breeze";
          theme = "Breeze";
        };
      };

      configFile = {
        kiorc.Confirmations.ConfirmEmptyTrash = true;
        breezerc.Style.MenuOpacity = 60;
        kdeglobals.KScreen.ScaleFactor = lib.mkIf (cfg.scale != null) cfg.scale;
        # Keep System Settings' lock-screen preview in sync with the active image.
        kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General".PreviewImage = lib.mkIf (
          cfg.wallpaper != null
        ) cfg.wallpaper;
        krdpserverrc.General = {
          Autostart = cfg.krdp.enable;
          ListenPort = cfg.krdp.port;
          Quality = cfg.krdp.quality;
          SystemUserEnabled = cfg.krdp.enable;
        };

        # Plasma 6.3+ reads window decoration from `org.kde.kdecoration3`,
        # while plasma-manager currently writes the legacy
        # `org.kde.kdecoration2` section. Mirror the selected Breeze decoration.
        kwinrc = {
          Xwayland.Scale = lib.mkIf (cfg.scale != null) cfg.scale;
          ElectricBorders = {
            TopLeft = "ApplicationLauncher";
            TopRight = "ShowDesktop";
            BottomLeft = "ActivityManager";
            BottomRight = "None";
          };
          "Effect-overview".BorderActivate = "3";
          Plugins.kwin4_effect_shapecornersEnabled = true;
          "Round-Corners" = {
            InactiveCornerRadius = 8;
            Size = 8;
          };
          "org.kde.kdecoration3" = {
            inherit (config.programs.plasma.workspace.windowDecorations) library theme;
          };
          Wayland.InputMethod = "${osConfig.i18n.inputMethod.package}/share/applications/fcitx5-wayland-launcher.desktop";
        };
      };
    };

    xdg.configFile."systemd/user/plasma-workspace.target.wants/app-org.kde.krdpserver.service" = {
      enable = cfg.krdp.enable;
      force = true;
      source = "${pkgs.kdePackages.krdp}/share/systemd/user/app-org.kde.krdpserver.service";
    };

    # Konsole
    programs.konsole = rec {
      enable = true;
      customColorSchemes.breeze-blur = ./breeze-blur.colorscheme;
      defaultProfile = profiles.default.name;
      profiles.default = {
        name = "Default";
        colorScheme = "breeze-blur";
        command = lib.getExe pkgs.zsh;
        font = {
          name = "Cascadia Mono PL";
          size = 11;
        };
      };
    };

    # Unify look for GTK applications
    gtk = {
      enable = true;
      cursorTheme = {
        name = "breeze_cursors";
        inherit (config.programs.plasma.workspace.cursor) size;
      };
      iconTheme.name = "breeze-dark";
      theme.name = "Breeze";
      gtk3.extraConfig.gtk-im-module = "fcitx";
      gtk4 = {
        theme = config.gtk.theme;
        extraConfig.gtk-im-module = "fcitx";
      };
    };

    # GPG with pinentry-qt for KDE
    services.gpg-agent.pinentry.package = pkgs.pinentry-qt;

    # KDE Connect
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };

    # Keep ksshaskpass discoverable by the host portal and use it only when
    # OpenSSH has no controlling terminal. Interactive ssh-add must read the
    # passphrase directly from its TTY; forcing askpass there causes needless
    # graphical retries. The systemd mirror covers KDE-launched applications.
    home.packages = [
      pkgs.kde-rounded-corners
      pkgs.kdePackages.kdeplasma-addons
      pkgs.kdePackages.ksshaskpass
    ];

    home.sessionVariables = {
      SSH_ASKPASS = lib.getExe pkgs.kdePackages.ksshaskpass;
    };
    systemd.user.sessionVariables = {
      SSH_ASKPASS = lib.getExe pkgs.kdePackages.ksshaskpass;
    };

    # Hack: fix .gtkrc-2.0 becoming a real file instead of a symlink
    home.activation.rm-gtkrc-2-0 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ ! -L $HOME/.gtkrc-2.0 ]; then
        rm -f $HOME/.gtkrc-2.0
      fi
    '';
  };
}
