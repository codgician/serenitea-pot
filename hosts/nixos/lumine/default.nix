{
  system = "aarch64-linux";
  modules = [
    ./disks.nix
    ./hardware.nix
    ./system.nix
    ./reverse-proxies.nix
  ];
}
