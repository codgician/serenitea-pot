{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "x86_64-linux";
  modules = [
    ./system.nix
    ./disks.nix
    ./hardware.nix
    ./network.nix
    ./lab.nix
    ./proxmox.nix
    ./monitoring.nix
  ];
}
