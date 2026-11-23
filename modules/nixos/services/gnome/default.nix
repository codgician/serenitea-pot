{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.gnome;
  types = lib.types;
  usersWithAvatars = lib.filterAttrs (
    _: user: user.enable && user.avatar != null
  ) config.codgician.users;
  gnomeAvatars = lib.mapAttrs (
    name: user:
    pkgs.runCommand "${name}-gnome-avatar.png" { } ''
      ${lib.getExe pkgs.imagemagick} ${lib.escapeShellArg "${user.avatar}[0]"} \
        -resize '512x512>' -strip png:$out

      if (( $(${lib.getExe' pkgs.coreutils "stat"} --format=%s "$out") > 1048576 )); then
        echo "GNOME avatar for ${name} exceeds AccountsService's 1 MiB limit" >&2
        exit 1
      fi
    ''
  ) usersWithAvatars;
  # rime-ice renames upstream default.yaml to rime_ice_suggestion.yaml; expose it
  # as default.yaml in the shared Rime data dir so rime_ice works out of the box.
  rimeIceDefault = pkgs.runCommand "rime-ice-default" { } ''
    mkdir -p $out/share/rime-data
    cp ${pkgs.rime-ice}/share/rime-data/rime_ice_suggestion.yaml $out/share/rime-data/default.yaml
  '';
  ibusRime = pkgs.ibus-engines.rime.override {
    rimeDataPkgs = [
      pkgs.rime-ice
      rimeIceDefault
    ];
  };
in
{
  options.codgician.services.gnome = {
    enable = lib.mkEnableOption "Gnome Desktop.";

    autoLoginUser = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Specify an auto-login user if you want to enable auto login.";
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      xserver = {
        enable = true;
        xkb.layout = "us";
      };

      fwupd.enable = true;

      displayManager = {
        defaultSession = "gnome";
        gdm.enable = true;

        autoLogin = lib.mkIf (cfg.autoLoginUser != null) {
          enable = true;
          user = cfg.autoLoginUser;
        };
      };

      desktopManager.gnome = {
        enable = true;
        extraGSettingsOverrides = ''
          [org.gnome.mutter]
          experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
        '';
      };

      gnome = {
        core-apps.enable = true;
        core-developer-tools.enable = true;
        core-os-services.enable = true;
        core-shell.enable = true;
        gcr-ssh-agent.enable = true;
        glib-networking.enable = true;
        gnome-keyring.enable = true;
        gnome-remote-desktop.enable = true;
        gnome-settings-daemon.enable = true;
        localsearch.enable = true;
        sushi.enable = true;
        tinysparql.enable = true;
      };
    };

    programs = {
      dconf.enable = true;

      # Open KDE Connect firewall ports for GSConnect without installing the KDE daemon.
      kdeconnect = {
        enable = true;
        package = pkgs.gnomeExtensions.gsconnect;
      };

      # Enable "Open in Terminal" context menu in Nautilus.
      nautilus-open-any-terminal = {
        enable = true;
        terminal = "kgx";
      };
    };

    # Prefer native IBus with Rime-Ice under GNOME unless Fcitx 5 is explicitly enabled.
    i18n.inputMethod = lib.mkIf (!config.codgician.services.fcitx5.enable) {
      enable = true;
      type = "ibus";
      ibus = {
        waylandFrontend = true;
        engines = [
          ibusRime
          pkgs.ibus-engines.libpinyin
        ];
      };
    };

    environment.sessionVariables = {
      # Nixpkgs Electron wrappers use this to enable native Wayland and its IME protocol.
      NIXOS_OZONE_WL = "1";
      # Use Libadwaita-styled Wayland CSD titlebars for Qt5/Qt6 applications.
      QT_WAYLAND_DECORATION = "adwaita";
    };

    # Unify Qt5/Qt6 look and Wayland decorations with GNOME Adwaita.
    qt = {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita-dark";
    };

    # Enable PAM auto-unlock for gnome-keyring (required for credential storage).
    security.pam.services.gdm-password.enableGnomeKeyring = true;

    # GNOME and GDM read IconFile from AccountsService. SetIconFile preserves
    # AccountsService's other mutable per-user settings while updating the icon.
    systemd.services.gnome-user-avatars = lib.mkIf (builtins.attrNames gnomeAvatars != [ ]) {
      description = "Configure declarative GNOME user avatars";
      wantedBy = [ "display-manager.service" ];
      before = [ "display-manager.service" ];
      requires = [ "accounts-daemon.service" ];
      after = [ "accounts-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: avatar: ''
          uid="$(${lib.getExe' pkgs.coreutils "id"} -u ${lib.escapeShellArg name})"
          ${lib.getExe' config.systemd.package "busctl"} call \
            org.freedesktop.Accounts \
            "/org/freedesktop/Accounts/User$uid" \
            org.freedesktop.Accounts.User \
            SetIconFile \
            s \
            ${lib.escapeShellArg (toString avatar)}
        '') gnomeAvatars
      );
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gnome ];
    };

    # Persist GNOME Remote Desktop credentials and TLS certificates.
    codgician.system.impermanence.extraItems = [
      {
        path = "/var/lib/gnome-remote-desktop";
        type = "directory";
        user = "gnome-remote-desktop";
        group = "gnome-remote-desktop";
        mode = "0700";
      }
    ];

    environment.systemPackages = with pkgs; [
      clinfo
      mesa-demos
      pciutils
      qadwaitadecorations
      qadwaitadecorations-qt6
      usbutils
      vulkan-tools
      wayland-utils
    ];
  };
}
