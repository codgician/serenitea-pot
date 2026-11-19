{
  lib,
  pkgs,
  inputs,
  ...
}:

inputs.terranix.lib.terranixConfiguration {
  inherit pkgs;
  inherit (pkgs.stdenv.hostPlatform) system;
  extraArgs = { inherit lib; };
  # The records read `config.codgician.inventory` like every host does.
  modules = lib.codgician.getFolderPaths ./. ++ [ ../../modules/generic/inventory ];
}
