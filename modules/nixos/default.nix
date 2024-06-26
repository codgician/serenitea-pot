{ lib, ... }:

let
  mkModule = paths: ({ ... }: { imports = paths; });
  paths = rec {
    overlays = [ ../overlays ];
    users = [ ../users ];
    nixos = lib.codgician.getImports ./.;
    default = overlays ++ users ++ nixos;
  };
in
builtins.mapAttrs (_: v: mkModule v) paths
