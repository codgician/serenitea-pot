{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-linux";
  modules = [
    (import ./disks.nix { })
    ./hardware.nix
    ./system.nix
  ];
}
