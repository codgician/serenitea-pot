{
  system = "x86_64-linux";
  cudaSupport = true;
  modules = [
    ./system.nix
    (import ./disks.nix { })
    ./hardware.nix
    ./network.nix
    ./lab.nix
    ./proxmox.nix
    ./monitoring.nix
  ];
}
