{
  system = "x86_64-linux";
  cudaSupport = true;
  roles = [ ];
  modules = [
    ./system.nix
    ./hardware.nix
  ];
}
