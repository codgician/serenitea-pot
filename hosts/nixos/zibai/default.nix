{
  system = "x86_64-linux";
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
  ];
}
