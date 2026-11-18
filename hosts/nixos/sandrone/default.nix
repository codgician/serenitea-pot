{
  system = "aarch64-linux";
  roles = [ "desktop" ];
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
  ];
}
