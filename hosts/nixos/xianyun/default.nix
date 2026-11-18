{
  system = "x86_64-linux";
  roles = [ "edge" ];
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
  ];
}
