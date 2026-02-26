{
  lib,
  pkgs,
  ...
}:
{
  # Waydroid kiosk setup
  # Auto-login to a locked system user running Waydroid in Cage compositor

  # Kiosk user - system user with no password (locked account)
  users.users.kiosk = {
    isSystemUser = true;
    group = "kiosk";
    home = "/home/kiosk";
    createHome = true;
    shell = pkgs.bash;
    extraGroups = [
      "video"
      "render"
      "tty"
      "input"
      "seat"
    ];
  };

  users.groups.kiosk = { };

  # Waydroid container (auto-selects waydroid-nftables when nftables is enabled)
  virtualisation.waydroid.enable = true;

  # PipeWire for audio (required for Waydroid audio passthrough)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.extraConfig = {
      # Fix audio output to ALC892 analog (not HDMI) and set default volume to 100%
      "50-kiosk-default-sink" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "alsa_output.pci-0000_00_1b.0.analog-stereo"; } ];
            actions.update-props = {
              "priority.session" = 1200;
              "node.softvolume.default" = 1.0; # 100% volume
            };
          }
          {
            matches = [ { "node.name" = "alsa_output.pci-0000_00_03.0.hdmi-stereo"; } ];
            actions.update-props = {
              "priority.session" = 500;
            };
          }
        ];
      };
      # Disable state restoration for deterministic kiosk behavior
      "51-kiosk-no-restore" = {
        "wireplumber.settings" = {
          "device.restore-profile" = false;
          "device.restore-routes" = false;
          "node.restore-default-targets" = false;
        };
      };
    };
  };

  # Seat management for Wayland compositors
  services.seatd.enable = true;

  # greetd auto-login with Cage compositor running Waydroid
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.cage} -s -- ${lib.getExe pkgs.waydroid} show-full-ui";
        user = "kiosk";
      };
    };
  };

  # Prevent TTY switching (security hardening)
  services.logind.settings.Login.NAutoVTs = 0;

  # XDG portal for Wayland (Cage uses wlroots)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [
      "wlr"
      "gtk"
    ];
  };

  # Persist waydroid data (images, config)
  # Note: ZFS dataset needs acltype=posixacl for Android compatibility
  # (configured in disks.nix for zroot/persist)
  codgician.system.impermanence.extraItems = [
    {
      type = "directory";
      path = "/var/lib/waydroid";
    }
  ];

  # Fix permissions on /var/lib/waydroid so kiosk user can verify initialization
  # waydroid CLI checks os.path.isfile(waydroid.cfg) and os.path.isdir(rootfs)
  # which fail if user lacks read+execute permissions on the directory
  # Use 'z' type to set permissions on existing directory (waydroid service creates it as 0750)
  systemd.tmpfiles.rules = [
    "z /var/lib/waydroid 0751 root kiosk -"
  ];

  # Adds wayland-script for managability
  # Install `libhoudini` / `libndk` arm translation using
  # `sudo waydroid-script install libhoudini` (or `libndk`)
  environment.systemPackages = with pkgs.nur.repos.codgician; [ waydroid-script ];
}
