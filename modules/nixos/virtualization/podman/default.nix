{ config, lib, ... }:
let
  cfg = config.codgician.virtualization.podman;
  systemCfg = config.codgician.system;
in
{
  options.codgician.virtualization.podman.enable = lib.mkEnableOption ''
    Enable podman.
  '';

  config = lib.mkIf cfg.enable {
    # Podman configurations
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    # Set podman as oci-container backend
    virtualisation.oci-containers.backend = "podman";

    # Persist data
    environment = lib.optionalAttrs (systemCfg ? impermanence) {
      persistence.${systemCfg.impermanence.path}.directories = [
        "/var/lib/containers"
      ];
    };
  };
}
