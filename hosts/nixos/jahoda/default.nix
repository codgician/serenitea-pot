{
  system = "x86_64-linux";
  roles = [
    "desktop"
    "work"
    "libvirt"
  ];
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
    ./vms
  ];
}
