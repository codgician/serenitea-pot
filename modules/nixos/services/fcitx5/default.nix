{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.fcitx5;
  oskPackage = pkgs.nur.repos.codgician.fcitx5-osk;
in
{
  options.codgician.services.fcitx5 = {
    enable = lib.mkEnableOption "Fcitx 5 input method.";

    osk = {
      enable = lib.mkEnableOption "Fcitx 5 Osk, an on-screen keyboard for touch/tablet devices.";

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = oskPackage;
        defaultText = lib.literalExpression "pkgs.nur.repos.codgician.fcitx5-osk";
        description = "The fcitx5-osk package, exposed so desktop modules can reference its KWin launcher desktop entry.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.variables.XMODIFIERS = "@im=fcitx";
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        addons = [
          pkgs.fcitx5-rime
          pkgs.qt6Packages.fcitx5-chinese-addons
          pkgs.fcitx5-mellow-themes
        ];
        waylandFrontend = true;
        settings.globalOptions."Hotkey/TriggerKeys"."0" = "Control+space";
        settings.addons = {
          classicui.globalSection.Theme = "kwinblur-mellow-youlan-dark";
          pinyin.globalSection.CloudPinyinEnabled = true;
        };
        settings.inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            "Default Layout" = "us";
            DefaultIM = "pinyin";
            Name = "Default";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "pinyin";
        };
      };
    };

    # Fcitx 5 Osk: register the desktop entries/D-Bus services shipped in the
    # package, and start the key helper that fixes modifier events on Wayland.
    environment.systemPackages = lib.mkIf cfg.osk.enable [ cfg.osk.package ];
    services.dbus.packages = lib.mkIf cfg.osk.enable [ cfg.osk.package ];
    systemd.packages = lib.mkIf cfg.osk.enable [ cfg.osk.package ];
    # `systemd.packages` ignores the unit's `[Install]` section.
    systemd.services.fcitx5-osk-key-helper.wantedBy = lib.mkIf cfg.osk.enable [ "multi-user.target" ];
  };
}
