{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "aarch64-linux";
  modules = [
    (import ./disks.nix { })
    ./system.nix
    ./hardware.nix
  ];
}
