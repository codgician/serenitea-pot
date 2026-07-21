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
  allSides =
    value:
    lib.genAttrs [
      "top"
      "right"
      "bottom"
      "left"
    ] (_: value);
  allCorners =
    value:
    lib.genAttrs [
      "topLeft"
      "topRight"
      "bottomRight"
      "bottomLeft"
    ] (_: value);

  dockPanelSettings = {
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
        corner = allCorners 8;
      };
      margin = {
        enabled = true;
        side = allSides 6;
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

  dockPanelColorizer = {
    plasmaPanelColorizer = {
      general = {
        enable = true;
        hideWidget = true;
      };
      settings.General.globalSettings = builtins.toJSON dockPanelSettings;
    };
  };

in
{
  options.codgician.codgi.plasma = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.services.desktopManager.plasma6.enable;
      description = "Enable dotfiles for KDE plasma desktop.";
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
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;
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
        # Top bar: kickoff (NixOS) + app menu (left) | spacer | tray + clock (right)
        {
          location = "top";
          height = 32;
          floating = true;
          opacity = "translucent";
          alignment = "center";
          lengthMode = "fill";
          hiding = "normalpanel";
          widgets = [
            "org.kde.plasma.marginsseparator"
            {
              name = "org.kde.plasma.kickoff";
              config.General.icon = "nix-snowflake-white";
            }
            {
              appMenu.compactView = false;
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
                  size = 10;
                };
              };
            }
            # Peek at desktop, top-right corner (macOS-style hot corner).
            "org.kde.plasma.showdesktop"
          ];
        }

        # Bottom dock: centered, fits content, hides under windows (macOS feel)
        {
          location = "bottom";
          height = 56;
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

        # Plasma 6.3+ reads window decoration from `org.kde.kdecoration3`,
        # while plasma-manager currently writes the legacy
        # `org.kde.kdecoration2` section. Mirror the selected Breeze decoration.
        kwinrc = {
          "org.kde.kdecoration3" = {
            inherit (config.programs.plasma.workspace.windowDecorations) library theme;
          };
          Wayland.InputMethod = "${osConfig.i18n.inputMethod.package}/share/applications/fcitx5-wayland-launcher.desktop";
        };
      };
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
    home.packages = [ pkgs.kdePackages.ksshaskpass ];

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
