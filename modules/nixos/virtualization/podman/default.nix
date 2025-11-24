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

    # Create containers user for rootful podman with userns=auto
    # https://docs.podman.io/en/v5.7.0/markdown/podman-run.1.html#userns-mode
    users.users.containers = {
      group = "containers";
      isSystemUser = true;
      subUidRanges = [
        {
          count = 2147483647;
          startUid = 2147483648;
        }
      ];
      subGidRanges = [
        {
          count = 2147483647;
          startGid = 2147483648;
        }
      ];
    };
    users.groups.containers = { };

    # Persist data
    codgician.system.impermanence.extraItems = [
      {
        type = "directory";
        path = "/var/lib/containers";
      }
    ];
  };
}
