{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.services.plasma;
  types = lib.types;
in
lib.optionalAttrs (lib.version >= "24.05") {
  options.codgician.services.plasma = {
    enable = lib.mkEnableOption "Enable Plasma Desktop.";

    wayland = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable Wayland support for Plasma Desktop.";
    };

    autoLoginUser = lib.mkOption {
      type = types.str;
      default = "";
      description = "Specify an auto-login user if you want to enable auto login.";
    };

    displayManager = lib.mkOption {
      type = types.strMatching "^(sddm|lightdm)$";
      default = "sddm";
      example = "sddm";
      description = "Select display manager to use (`sddm` or `lightdm`).";
    };

    mobile = {
      enable = lib.mkEnableOption "Enable Plasma Mobile.";
    };
  };

  config = lib.mkIf (cfg.enable || cfg.mobile.enable) {
    services = {
      xserver = {
        enable = true;
        displayManager = {
          sddm = lib.mkIf (cfg.displayManager == "sddm") {
            enable = true;
            enableHidpi = true;
            theme = "breeze";
          };

          lightdm = lib.mkIf (cfg.displayManager == "lightdm") {
            enable = true;
            # Workaround for autologin only working at first launch.
            # A logout or session crashing will show the login screen otherwise.
            extraSeatDefaults = ''
              session-cleanup-script=${pkgs.procps}/bin/pkill -P1 -fx ${pkgs.lightdm}/sbin/lightdm
            '';
          };
        };
      };

      desktopManager.plasma6 = {
        enable = cfg.enable;
        enableQt5Integration = true;
      };
    };

    i18n.inputMethod.fcitx5.plasma6Support = true;

    # Enable dconf
    programs.dconf.enable = true;

    # Auto unlock Kwallet
    security.pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };

    # Auto-login
    services.xserver.displayManager.autoLogin = lib.mkIf (builtins.stringLength cfg.autoLoginUser > 0) {
      enable = true;
      user = cfg.autoLoginUser;
    };

    # Configure keymap in X11
    services.xserver.xkb.layout = "us";

    # Install optional dependencies
    services.fwupd.enable = true;
    environment.systemPackages = with pkgs; [
      breeze-gtk
      pciutils
      usbutils
      clinfo
      glxinfo
      vulkan-tools
      wayland-utils
      aha
      kdePackages.kio-admin
    ] ++ (lib.optionals (cfg.mobile.enable) (with kdePackages; [ 
      plasma-mobile 
      plasma-nano 
      pkgs.maliit-framework
      pkgs.maliit-keyboard
    ]));

    # Enable services to ensure UI not broken
    hardware.bluetooth.enable = true;
    hardware.pulseaudio.enable = true;
    networking.networkmanager.enable = true;

    # Required for autorotate
    hardware.sensor.iio.enable = lib.mkDefault true;

    # todo: remove
    # hack to fix conflict
    programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
  };
}
