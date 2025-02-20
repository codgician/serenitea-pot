{ lib, ... }:

lib.codgician.mkNixosSystem {
  hostName = builtins.baseNameOf ./.;
  system = "aarch64-linux";
  modules = [
    ./hardware.nix
    ./system.nix
    ./tpm.nix
    ./wireless.nix
  ];
}
