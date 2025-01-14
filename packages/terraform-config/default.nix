{ lib, inputs, ... }:

lib.codgician.forAllSystems (
  pkgs:
  inputs.terranix.lib.terranixConfiguration {
    inherit pkgs;
    inherit (pkgs) system;
    extraArgs = { inherit lib; };
    modules = lib.codgician.getFolderPaths ./.;
  }
)
