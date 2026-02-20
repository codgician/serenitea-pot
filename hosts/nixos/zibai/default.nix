{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-linux";
  modules = [
    ./disks.nix
    ./system.nix
    ./hardware.nix
    ./waydroid.nix
  ];
}
