{ outputs, lib, ... }:
{
  boot.isContainer = true;

  networking = {
    interfaces.enp67s0f0v1.useDHCP = true;

    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
    useNetworkd = true;
  };

  # Ensure to use the same driver version as paimon
  environment.systemPackages = [ 
    outputs.nixosConfigurations.paimon.config.hardware.nvidia.package.bin 
  ];

  services.resolved.enable = true;

  nixpkgs.config.cudaSupport = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
