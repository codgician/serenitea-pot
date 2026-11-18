{
  system = "x86_64-linux";
  roles = [
    "server"
    "hypervisor"
    "libvirt"
  ];
  modules = [
    ./disks.nix
    ./hardware.nix
    ./system.nix
    ./vms
  ];
}
