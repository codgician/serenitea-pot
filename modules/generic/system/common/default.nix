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

    inChina = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this machine is located in mainland China. Consumed by
        modules that need region-specific behavior, e.g. preferring CN
        mirrors for the nix binary cache, or downloading models from
        ModelScope instead of Hugging Face for vLLM.
      '';
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
