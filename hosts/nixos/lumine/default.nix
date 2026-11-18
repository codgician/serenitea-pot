{
  system = "aarch64-linux";
  roles = [ "edge" ];
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
  ];
}
