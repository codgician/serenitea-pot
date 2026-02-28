# NixOS VM tests
#
# Run: nix build .#checks.x86_64-linux.<testName>
args@{ lib, ... }:

let
  testNames = lib.codgician.getFolderNames ./.;
in
lib.mergeAttrsList (map (name: import ./${name} args) testNames)
