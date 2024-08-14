{
  system = "aarch64-linux";
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
  ];
}
