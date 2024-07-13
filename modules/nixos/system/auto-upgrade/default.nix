{ config, lib, pkgs, ... }:
let
  cfg = config.codgician.system.auto-upgrade;
in
{
  options.codgician.system.auto-upgrade = {
    enable = lib.mkEnableOption "Enable system auto upgrading.";
  };

  config = lib.mkIf cfg.enable {
    # Auto upgrade
    system.autoUpgrade = {
      enable = true;
      dates = "daily";
      operation = "switch";
      allowReboot = true;
      rebootWindow = {
        lower = "03:00";
        upper = "05:00";
      };
    };

    # Nix garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
    };
  };
}
