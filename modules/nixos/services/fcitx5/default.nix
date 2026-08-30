{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.services.fcitx5;
in
{
  options.codgician.services.fcitx5.enable = lib.mkEnableOption "Fcitx 5 input method.";

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
  };
}
