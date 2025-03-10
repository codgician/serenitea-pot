{ config, lib, ... }:
let
  cfg = config.codgician.system.brew;
in
{
  options.codgician.system.brew = {
    enable = lib.mkEnableOption "Homebrew packages";

    casks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "google-chrome"
        "visual-studio-code"
      ];
      description = ''
        a list of apps to install via Homebrew Cask.
        The full list of available apps can be found at https://formulae.brew.sh/cask/.
      '';
    };

    masApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.positive;
      default = { };
      example = {
        Xcode = 497799835;
        Developer = 640199958;
      };
      description = ''
        An attr set of apps to install via Mac App Store.
        Internally it uses `mas-cli`, check out https://github.com/mas-cli/mas to learn more.
      '';
    };

    taps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "homebrew/cask-fonts" ];
      description = ''
        a list of taps to add to Homebrew.
        The full list of available taps can be found at https://formulae.brew.sh/.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Homebrew
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        upgrade = true;
        cleanup = "zap";
      };

      inherit (cfg) masApps taps;
      casks = builtins.map (name: {
        inherit name;
      }) cfg.casks;

      global = {
        autoUpdate = true;
        brewfile = true;
      };
    };
  };
}
