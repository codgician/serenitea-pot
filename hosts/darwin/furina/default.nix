{ lib, ... }:

lib.codgician.mkDarwinSystem {
  hostName = builtins.baseNameOf ./.;
  system = "aarch64-darwin";
  modules = [
    ./system.nix
  ];
}
