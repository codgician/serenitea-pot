{ config, lib, ... }:
let
  cfg = config.codgician.virtualization.podman;
  types = lib.types;
in
{
  options.codgician.virtualization.podman.enable = lib.mkEnableOption ''
    Enable podman.
  '';

  config.virtualisation.podman = lib.mkIf cfg.enable {
    enable = true;
    dockerCompat = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };
}
