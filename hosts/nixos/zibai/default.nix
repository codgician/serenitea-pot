{
  system = "x86_64-linux";
  roles = [ "server" ];
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
  ];
}
