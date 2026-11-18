{
  system = "aarch64-linux";
  roles = [ "edge" ];
  modules = [
    ./disks.nix
    ./hardware.nix
    ./system.nix
  ];
}
