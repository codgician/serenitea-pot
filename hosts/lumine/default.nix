{
  system = "x86_64-linux";
  modules = [
    ./hardware.nix
    ./system.nix
    ./reverse-proxies.nix
  ];
}
