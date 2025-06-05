{
  lib,
  pkgs,
  options ?
    (lib.codgician.mkNixosSystem {
      hostName = "nixos";
      inherit (pkgs) system;
    }).options,
  nixos-docs,
  ...
}:

nixos-docs.override { inherit options; }
