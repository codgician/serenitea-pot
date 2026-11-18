{
  system = "x86_64-linux";
  roles = [
    "server"
    "hypervisor"
    "libvirt"
  ];
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
    ./vms
  ];
}
