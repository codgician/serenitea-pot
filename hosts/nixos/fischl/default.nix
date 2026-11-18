{
  system = "x86_64-linux";
  roles = [ "server" ];
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
    ./vms
  ];
}
