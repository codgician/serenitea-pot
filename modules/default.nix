# Export OS modules

{ lib, ... }:

let
  mkModule =
    paths:
    (
      { ... }:
      {
        imports = paths;
      }
    );
  paths = rec {
    generic = lib.codgician.getFolderPaths ./generic;
    darwin = generic ++ (lib.codgician.getFolderPaths ./darwin);
    nixos = generic ++ (lib.codgician.getFolderPaths ./nixos);
  };
in
builtins.mapAttrs (_: v: mkModule v) paths
