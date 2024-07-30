# Export terraform configuration

{ lib, pkgs, terranix, ... }:

let
  mkTerranixConfig = modules: terranix.lib.terranixConfiguration {
    inherit pkgs modules;
    inherit (pkgs) system;
    extraArgs = { inherit lib; };
  };
in
mkTerranixConfig (lib.codgician.getFolderPaths ./.)
