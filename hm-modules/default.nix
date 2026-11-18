# Export home manager modules for each user

{ lib, ... }:
lib.genAttrs (lib.codgician.getFolderNames ./.) (
  user:
  let
    generic = lib.codgician.getFolderPaths ./${user}/generic;
  in
  lib.mapAttrs (_: imports: { inherit imports; }) {
    inherit generic;
    darwin = generic ++ lib.codgician.getFolderPaths ./${user}/darwin;
    nixos = generic ++ lib.codgician.getFolderPaths ./${user}/nixos;
  }
)
