{
  system = "x86_64-linux";
  cudaSupport = true;
  roles = [
    "server"
    "hypervisor"
  ];
  modules = [
    ./system.nix
    ./disks.nix
    ./hardware.nix
    ./network.nix
    ./lab.nix
    ./proxmox.nix
    ./monitoring.nix
  ];
}
