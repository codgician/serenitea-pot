{ lib, ... }:

let
  mkModule = paths: ({ ... }: { imports = paths; });
  paths = rec {
    overlays = [ ../overlays ];
    users = [ ../users ];
    darwin = lib.codgician.getImports ./.;
    default = overlays ++ users ++ darwin;
  };
in
builtins.mapAttrs (_: v: mkModule v) paths
