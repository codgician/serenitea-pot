{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.system.common;
in
{
  options.codgician.system.common = {
    enable = lib.mkOption {
      default = true;
      description = "Common options shared accross all systems.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Set up nix-direnv
    programs.direnv.nix-direnv.enable = true;

    # Fonts
    fonts.packages = with pkgs; [
      cascadia-code
      nerd-fonts.caskaydia-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
  };
}
