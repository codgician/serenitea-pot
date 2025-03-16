{
  lib,
  pkgs,
  inputs,
  ...
}:

inputs.terranix.lib.terranixConfiguration {
  inherit pkgs;
  inherit (pkgs) system;
  extraArgs = { inherit lib; };
  modules = lib.codgician.getFolderPaths ./.;
}
