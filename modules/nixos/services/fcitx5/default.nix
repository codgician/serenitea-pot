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
        settings.globalOptions."Hotkey/TriggerKeys"."0" = "Super+space";
        settings.addons = {
          classicui.globalSection.Theme = "kwinblur-mellow-youlan-dark";
          pinyin.globalSection.CloudPinyinEnabled = true;
        };
      };
    };
  };
}
