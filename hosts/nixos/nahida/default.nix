{
  system = "x86_64-linux";
  cudaSupport = true;
  modules = [
    ./system.nix
    ./hardware.nix
  ];
}
