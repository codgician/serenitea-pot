{
  system = "x86_64-linux";
  roles = [
    "server"
    "hypervisor"
  ];
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
    ./vms
  ];
}
