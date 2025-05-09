{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.codgician.virtualization.podman;
  systemCfg = config.codgician.system;
in
{
  options.codgician.virtualization.podman.enable = lib.mkEnableOption "podman";

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

    # Mount executables for nvidia
    hardware.nvidia-container-toolkit = {
      mount-nvidia-executables = true;
      mount-nvidia-docker-1-directories = true;
    };

    # Global packages
    environment.systemPackages = with pkgs; [ podman-tui ];

    # Persist data
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/containers";
      }
    ];
  };
}
