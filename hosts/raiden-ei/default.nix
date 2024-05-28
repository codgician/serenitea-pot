{ inputs, ... }: {
  system = "x86_64-darwin";
  modules = [
    ./system.nix
  ];
}
