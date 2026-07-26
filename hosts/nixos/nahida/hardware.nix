{ pkgs, lib, ... }:
{
  boot.isContainer = true;

  networking = {
    interfaces.enp193s0f0v1.useDHCP = true;

    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
    useNetworkd = true;
  };

  # Keep this selection in sync with Paimon's hardware.nvidia.package.
  environment.systemPackages = [
    pkgs.linuxPackages_6_18.nvidiaPackages.production.bin
  ];

  services.resolved.enable = true;

  nixpkgs.config.cudaSupport = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
