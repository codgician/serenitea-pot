{
  system = "x86_64-linux";
  roles = [ "server" ];
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
  ];
}
