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
      xserver.enable = true;
      displayManager = {
        defaultSession = "gnome";

        gdm = {
          enable = true;
        };

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

    # Enable dconf
    programs.dconf.enable = true;

    # Enable "Open in Terminal" context menu in Nautilus
    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "kgx"; # GNOME Console
    };

    # Enable PAM auto-unlock for gnome-keyring (required for credential storage)
    security.pam.services.gdm-password.enableGnomeKeyring = true;

    # Configure keymap in X11
    services.xserver.xkb.layout = "us";

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
      wlr.enable = true;
    };

    # Install optional dependencies
    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
      mesa-demos
      vulkan-tools
    ];
  };
}
