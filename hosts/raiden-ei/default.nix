{ lib, ... }:

lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-darwin";
  modules = [
    ./system.nix
  ];
}
