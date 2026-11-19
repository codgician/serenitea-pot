{
  system = "x86_64-linux";
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
  ];
}
