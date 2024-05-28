{ inputs, ... }: {
  system = "aarch64-darwin";
  modules = [
    ./system.nix
  ];
}
