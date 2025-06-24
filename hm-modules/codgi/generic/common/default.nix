{ pkgs, ... }:
{
  config = {
    # Install custom fonts
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      cascadia-code
    ];
  };
}
