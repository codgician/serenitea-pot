{ config, lib, ... }:
{
  options.codgician.system.brew.casks = lib.mkOption {
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

  config.homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraFlags = [
        "--force-cleanup"
      ];
    };

    casks = builtins.map (name: {
      inherit name;
    }) config.codgician.system.brew.casks;

    global = {
      autoUpdate = true;
      brewfile = true;
    };
  };
}
