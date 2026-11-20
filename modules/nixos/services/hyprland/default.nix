{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.hyprland;
  wallpaper = "${pkgs.hyprland}/share/hypr/wall2.png";
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
  # wlr-randr requires an exact refresh rate; selecting by resolution lets the
  # compositor choose the preferred 4K refresh advertised by the monitor.
  formatWlrMode = mode: builtins.head (lib.splitString "@" mode);
  monitorToWlrArgs =
    monitor:
    lib.escapeShellArgs (
      [
        "--output"
        monitor.output
        "--on"
      ]
      ++ lib.optionals (monitor.mode != "preferred") [
        "--mode"
        (formatWlrMode monitor.mode)
      ]
      ++ lib.optionals (monitor.position != "auto") [
        "--pos"
        (lib.replaceStrings [ "x" ] [ "," ] monitor.position)
      ]
      ++ lib.optionals (monitor.scale != "auto") [
        "--scale"
        (toString monitor.scale)
      ]
    );
  greeterMonitorArgs = lib.concatMapStringsSep " " monitorToWlrArgs (
    builtins.filter (monitor: monitor.output != "") cfg.monitors
  );
  regreetApp = pkgs.writeShellScript "regreet-with-layout" ''
    ${lib.optionalString (
      greeterMonitorArgs != ""
    ) "${lib.getExe pkgs.wlr-randr} ${greeterMonitorArgs}"}
    exec ${lib.getExe config.programs.regreet.package}
  '';
  regreetSession = pkgs.writeShellScript "regreet-session" ''
    export SESSION_DIRS=${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
    exec ${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.cage} ${lib.escapeShellArgs config.programs.regreet.cageArgs} -- ${regreetApp}
  '';
  hyprlandUwsmSession = pkgs.writeTextFile {
    name = "hyprland-uwsm-session";
    destination = "/share/wayland-sessions/hyprland-uwsm.desktop";
    text = ''
      [Desktop Entry]
      Name=Hyprland
      Comment=Hyprland compositor managed by UWSM
      Exec=${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/Hyprland
      TryExec=${lib.getExe pkgs.uwsm}
      DesktopNames=Hyprland
      Type=Application
    '';
    derivationArgs.passthru.providedSessions = [ "hyprland-uwsm" ];
  };
in
{
  options.codgician.services.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop session";

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
      description = "Machine-specific monitor layout shared by ReGreet and Hyprland.";
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
        systemd.enable = true;
        recommendedServices.enable = true;
      };
      regreet = {
        enable = true;
        font = {
          name = "Noto Sans";
          package = pkgs.noto-fonts;
          size = 14;
        };
        settings = {
          skip_selection = false;
          background = {
            path = wallpaper;
            fit = "Cover";
          };
          GTK.application_prefer_dark_theme = true;
          appearance.greeting_msg = "Welcome back";
          widget.clock = {
            format = "%A, %B %-d  %I:%M %p";
            resolution = "1s";
          };
        };
      };
    };

    services = {
      greetd = {
        enable = true;
        settings.default_session.command = lib.mkForce "${regreetSession}";
      };
      # ReGreet must not offer the unmanaged Hyprland session: the user
      # services below are attached to the graphical session started by UWSM.
      gvfs.enable = true;
      tumbler.enable = true;
      displayManager.sessionPackages = lib.mkForce [ hyprlandUwsmSession ];

      gnome = {
        gcr-ssh-agent.enable = true;
        gnome-keyring.enable = true;
      };
    };

    security = {
      pam.services = {
        hyprlock = { };
        greetd.enableGnomeKeyring = true;
      };
    };

    # ReGreet stores its remembered user and session in this directory. The
    # upstream NixOS module already creates it through systemd-tmpfiles.
    codgician.system.impermanence.extraItems = [
      {
        path = "/var/lib/regreet";
        type = "directory";
        user = "greeter";
        group = "greeter";
        mode = "0755";
      }
    ];

    fonts.packages = with pkgs; [
      font-awesome
      nerd-fonts.symbols-only
      noto-fonts
    ];

    environment.systemPackages = with pkgs; [
      hyprland-qt-support
      hyprland-qtutils
      hyprpwcenter
    ];
  };
}
