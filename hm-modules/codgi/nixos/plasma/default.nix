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
      default =
        osConfig.services.desktopManager.plasma6.enable
        || osConfig.services.xserver.desktopManager.plasma5.enable;
      description = ''Enable dotfiles for KDE plasma desktop.'';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      kwin.effects = {
        blur = {
          enable = true;
          noiseStrength = 5;
          strength = 15;
        };
        shakeCursor.enable = true;
        snapHelper.enable = true;
      };

      panels = [
        {
          alignment = "center";
          floating = true;
          height = 44;
          hiding = "none";
          lengthMode = "fill";
          location = "bottom";
          widgets = [
            {
              name = "org.kde.plasma.kickoff";
              config.General.icon = "nix-snowflake-white";
            }

            "org.kde.plasma.panelspacer"

            {
              name = "org.kde.plasma.icontasks";
              config.General.launchers = [
                "applications:org.kde.dolphin.desktop"
                "applications:firefox.desktop"
                "applications:org.kde.konsole.desktop"
              ] ++ (lib.optional (config.codgician.codgi.vscode.enable) "applications:code.desktop");
            }

            "org.kde.plasma.panelspacer"
            "org.kde.plasma.marginsseparator"
            "org.kde.plasma.systemtray"
            "org.kde.plasma.digitalclock"
            "org.kde.plasma.showdesktop"
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
        plasmaashellrc.PlasmaViews.panelOpacity = 2;
      };
    };

    # Konsole
    programs.konsole = rec {
      enable = true;
      defaultProfile = profiles.default.name;
      profiles.default = {
        name = "Default";
        colorScheme = "Breeze";
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
  };
}
