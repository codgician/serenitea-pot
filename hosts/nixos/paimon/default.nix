{
  system = "x86_64-linux";
  cudaSupport = true;
  roles = [ "server" ];
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
