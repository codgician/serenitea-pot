{
  lib,
  pkgs,
  ...
}:
{
  options.codgician.system.common.inChina = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether this machine is located in mainland China. Consumed by
      modules that need region-specific behavior, e.g. preferring CN
      mirrors for the nix binary cache, or downloading models from
      ModelScope instead of Hugging Face.
    '';
  };

  config = {
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
