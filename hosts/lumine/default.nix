{
  system = "aarch64-linux";
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
    ./reverse-proxies.nix
  ];
}
