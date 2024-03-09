{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    (modulesPath + "/virtualisation/azure-common.nix")
    ./image.nix
  ];

  boot.growPartition = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "console=ttyS0,115200" ];

  swapDevices = [ ];
  zramSwap.enable = true;

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Azure specific configurations
  virtualisation.azure.agent.enable = true;
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig = {
    Restart = "on-failure";
  };
  services.cloud-init.network.enable = true;
  networking.useDHCP = false;
  networking.useNetworkd = true;
}
