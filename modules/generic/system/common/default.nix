{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.common;
in
{
  options.codgician.system.common = {
    enable = lib.mkOption {
      default = true;
      description = "Enable common options shared accross all systems.";
    };
  };

  config = lib.mkIf cfg.enable {
    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      cascadia-code
    ];
  };
}