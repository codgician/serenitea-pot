{ config, lib, pkgs, modulesPath, ... }: 
let
  mlxDrivers = [ "mlx4_en" "mlx4_core" "mlx5_core" ];
in
{
  imports = [
    (modulesPath + "/virtualisation/azure-agent.nix")
  ];

  boot.kernelParams = [ "console=ttyS0" "earlyprintk=ttyS0" "rootdelay=300" "panic=1" "boot.panic_on_fail" ];
  boot.initrd.kernelModules = [ "hv_vmbus" "hv_netvsc" "hv_utils" "hv_storvsc" ];
  boot.initrd.availableKernelModules = mlxDrivers;
  boot.growPartition = true;

  environment.systemPackages = with pkgs; [ cryptsetup sg3_utils ];

  services.udev.extraRules = with builtins; concatStringsSep "\n" (map
    (i: ''
      ENV{DEVTYPE}=="disk", KERNEL!="sda" SUBSYSTEM=="block", SUBSYSTEMS=="scsi", KERNELS=="?:0:0:${toString i}", ATTR{removable}=="0", SYMLINK+="disk/by-lun/${toString i}"
    '')
    (lib.range 1 15));

  virtualisation.azure.agent.enable = true;
  services.cloud-init.enable = true;
  systemd.services.cloud-config.serviceConfig.Restart = "on-failure";
  services.cloud-init.network.enable = true;

  # Accelerated Networking 
  systemd.network.networks."99-azure-unmanaged-devices.network" = {
    matchConfig.Driver = mlxDrivers;
    linkConfig.Unmanaged = "yes";
  };
}
