{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.hyprland;
  tomlFormat = pkgs.formats.toml { };
  defaultWallpaper = "${pkgs.hyprland}/share/hypr/wall2.png";
  effectiveWallpaper = if cfg.wallpaper != null then cfg.wallpaper else defaultWallpaper;

  usersWithAvatars = lib.filterAttrs (
    _: user: user.enable && user.avatar != null
  ) config.codgician.users;

  monitorValueType =
    with lib.types;
    oneOf [
      bool
      int
      float
      str
    ];
  monitorType = lib.types.submodule {
    freeformType = lib.types.attrsOf monitorValueType;
    options = {
      output = lib.mkOption {
        type = lib.types.str;
        description = "Hyprland output name, or an empty string as a fallback rule.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Resolution and refresh rate, or a Hyprland mode selector.";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Top-left output position in logical pixels.";
      };
      scale = lib.mkOption {
        type =
          with lib.types;
          oneOf [
            int
            float
            str
          ];
        default = "auto";
        description = "Output scale factor, or auto.";
      };
    };
  };

  explicitMonitors = builtins.filter (monitor: monitor.output != "") cfg.monitors;
  greeterOutputScales = lib.concatMapStringsSep "; " (
    monitor: "${monitor.output}:${toString monitor.scale}"
  ) (builtins.filter (monitor: monitor.scale != "auto") explicitMonitors);

  greeterSettings = {
    session.default = "Hyprland (UWSM)";
    appearance = {
      theme_mode = "dark";
      font_family = "Noto Sans";
      wallpaper = {
        path = toString effectiveWallpaper;
        fill_mode = "crop";
      };
    };
    cursor = {
      theme = "Adwaita";
      size = 24;
      path = "${pkgs.adwaita-icon-theme}/share/icons";
    };
    keyboard = {
      layout = "us";
      numlock = false;
    };
    idle.timeout = 300;
  }
  // lib.optionalAttrs (greeterOutputScales != "") {
    output.scales = greeterOutputScales;
  };

  # greetd starts sessions with a stripped environment; ensure dbus-run-session
  # and coreutils are on PATH for noctalia-greeter-session.
  noctaliaGreeterSession = pkgs.writeShellScript "noctalia-greeter-launch" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.dbus
      ]
    }:''${PATH:-/run/current-system/sw/bin}"
    exec ${lib.getExe pkgs.noctalia-greeter}
  '';

  # Use -F with an explicit compositor path so UWSM does not depend on
  # XDG_DATA_DIRS being populated before greetd launches the session.
  hyprlandUwsmSession = pkgs.writeTextFile {
    name = "hyprland-uwsm-session";
    destination = "/share/wayland-sessions/hyprland-uwsm-codgician.desktop";
    text = ''
      [Desktop Entry]
      Name=Hyprland (UWSM)
      Comment=Hyprland compositor managed by UWSM
      Exec=${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/start-hyprland
      TryExec=${lib.getExe pkgs.uwsm}
      DesktopNames=Hyprland
      Type=Application
    '';
    derivationArgs.passthru.providedSessions = [ "hyprland-uwsm-codgician" ];
  };
in
{
  options.codgician.services.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop session";

    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Wallpaper shared by Noctalia Greeter, desktop, and lock screen.";
    };

    monitors = lib.mkOption {
      type = lib.types.listOf monitorType;
      default = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];
      description = "Machine-specific monitor layout shared by Noctalia Greeter and Hyprland.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      dconf.enable = true;
      nautilus-open-any-terminal = {
        enable = true;
        terminal = "ghostty";
      };
      hyprland = {
        enable = true;
        withUWSM = true;
        xwayland.enable = true;
      };
      noctalia = {
        enable = true;
        # Home Manager owns the user service so config.toml updates trigger restarts.
        systemd.enable = false;
        recommendedServices.enable = true;
      };
    };

    services = {
      accounts-daemon.enable = true;
      fwupd.enable = true;
      greetd = {
        enable = true;
        settings.default_session.command = lib.mkForce "${noctaliaGreeterSession}";
      };
      gvfs.enable = true;
      tumbler.enable = true;
      xserver.xkb.layout = "us";

      gnome = {
        gcr-ssh-agent.enable = true;
        gnome-keyring.enable = true;
      };
    };

    environment.sessionVariables = {
      # Nixpkgs Electron wrappers use this to enable native Wayland and its IME protocol.
      NIXOS_OZONE_WL = "1";
      # Use Libadwaita-styled Wayland CSD titlebars for Qt5/Qt6 applications.
      QT_WAYLAND_DECORATION = "adwaita";
    };

    # Unify Qt5/Qt6 with Noctalia's dynamic palette via qt5ct/qt6ct (Darkly on Qt6, Breeze on Qt5).
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };

    security.pam.services.greetd.enableGnomeKeyring = true;

    # gnome-keyring.portal restricts UseIn=gnome, so route Secret portal requests explicitly under Hyprland.
    xdg.portal.config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };

    # Declarative greeter.toml for Noctalia Greeter; mutable sync/UI state lives in sync.toml.
    systemd.tmpfiles.settings."10-noctalia-greeter" = {
      "/var/lib/noctalia-greeter".d = {
        user = "greeter";
        group = "greeter";
        mode = "0750";
      };
      "/var/lib/noctalia-greeter/greeter.toml"."L+" = {
        argument = "${tomlFormat.generate "greeter.toml" greeterSettings}";
        user = "greeter";
        group = "greeter";
      };
    };

    # Expose user avatars via AccountsService for Noctalia Greeter.
    systemd.tmpfiles.rules = [
      "d /var/lib/AccountsService/icons 0755 root root -"
    ]
    ++ lib.mapAttrsToList (
      name: user: "L+ /var/lib/AccountsService/icons/${name} - - - - ${user.avatar}"
    ) usersWithAvatars;

    # Persist Noctalia Greeter mutable state (remembered user/session and synced palette).
    codgician.system.impermanence.extraItems = [
      {
        path = "/var/lib/noctalia-greeter";
        type = "directory";
        user = "greeter";
        group = "greeter";
        mode = "0750";
      }
    ];

    fonts.packages = with pkgs; [
      font-awesome
      nerd-fonts.symbols-only
      noto-fonts
    ];

    environment.systemPackages = with pkgs; [
      adw-gtk3
      darkly
      hyprland-guiutils
      hyprland-qt-support
      hyprlandUwsmSession
      hyprpwcenter
      kdePackages.breeze.qt5
      kdePackages.qqc2-desktop-style
      noctalia-greeter
      qadwaitadecorations
      qadwaitadecorations-qt6
      vulkan-tools
      wayland-utils
    ];
  };
}
