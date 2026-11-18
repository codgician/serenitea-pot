{
  system = "aarch64-linux";
  roles = [ "desktop" ];
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
  ];
}
