{
  system = "aarch64-linux";
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
  ];
}
