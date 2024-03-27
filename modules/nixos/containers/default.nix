{ config, lib, ... }:
let
  cfg = config.codgician.containers;
  types = lib.types;
in
{
  options.codgician.containers.enable = lib.mkEnableOption ''
    Enable container infrastructure (podman).
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
