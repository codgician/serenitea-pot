{
  config,
  lib,
  ...
}:
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
    # Set up nix-direnv
    programs.direnv.nix-direnv.enable = true;
  };
}
