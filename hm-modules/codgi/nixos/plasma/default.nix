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
in
{
  options.codgician.codgi.plasma = {
    enable = lib.mkOption {
      type = types.bool;
      default = osConfig.services.desktopManager.plasma6.enable;
      description = "Enable dotfiles for KDE plasma desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;
      fonts.general = {
        family = "Noto Sans";
        pointSize = 11;
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
          height = 36;
          floating = true;
          alignment = "center";
          lengthMode = "fill";
          hiding = "normalpanel";
          widgets = [
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
            # Breathing room between tray icons and the clock.
            {
              panelSpacer = {
                expanding = false;
                length = 10;
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
                  size = 11;
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
                launchers = [
                  "applications:org.kde.dolphin.desktop"
                  "applications:firefox.desktop"
                  "applications:org.kde.konsole.desktop"
                ]
                ++ (lib.optional (config.codgician.codgi.vscode.enable) "applications:code.desktop");
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

        iconTheme = "Breeze Dark";
        lookAndFeel = "org.kde.breezedark.desktop";
        theme = "breeze-dark";
      };

      configFile = {
        kiorc.Confirmations.ConfirmEmptyTrash = true;
        breezerc.Style.MenuOpacity = 60;
        plasmashellrc.PlasmaViews.panelOpacity = 2;
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
    };

    # GPG with pinentry-qt for KDE
    services.gpg-agent.pinentry.package = pkgs.pinentry-qt;

    # Hack: fix .gtkrc-2.0 becoming a real file instead of a symlink
    home.activation.rm-gtkrc-2-0 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ ! -L $HOME/.gtkrc-2.0 ]; then
        rm -f $HOME/.gtkrc-2.0
      fi
    '';
  };
}
