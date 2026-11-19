{
  system = "aarch64-darwin";
  roles = [ ];
  modules = [
    ./brew.nix
    ./system.nix
  ];
}
