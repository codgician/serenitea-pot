{
  system = "x86_64-linux";
  roles = [ "edge" ];
  modules = [
    ./disks.nix
    ./hardware.nix
    ./system.nix
  ];
}
